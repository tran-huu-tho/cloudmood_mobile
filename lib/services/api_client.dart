import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // 🌐 Cấu hình địa chỉ Server Backend:
  // Render Cloud Backend (Dự phòng khi Backend cục bộ không hoạt động)
  static const String remoteFallbackUrl =
      'https://cloudmood-backend.onrender.com';
  static const String configuredLocalUrl = String.fromEnvironment(
    'CLOUDMOOD_API_URL',
    defaultValue: '',
  );

  // Local Backend URL mặc định tùy theo môi trường (Android Emulator vs Web/iOS/Desktop)
  static String get defaultLocalUrl {
    if (configuredLocalUrl.trim().isNotEmpty) {
      return configuredLocalUrl.trim().replaceAll(RegExp(r'/$'), '');
    }
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  static String? _activeBaseUrl;
  static DateTime? _lastCheckTime;
  static bool _isChecking = false;

  static List<String> get _candidateBackendUrls {
    final candidates = <String>[
      if (_activeBaseUrl != null) _activeBaseUrl!,
      if (configuredLocalUrl.trim().isNotEmpty) configuredLocalUrl.trim(),
      if (defaultTargetPlatform == TargetPlatform.android)
        'http://127.0.0.1:3000',
      if (defaultTargetPlatform == TargetPlatform.android)
        'http://10.0.2.2:3000',
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android)
        'http://localhost:3000',
      remoteFallbackUrl,
    ];
    return candidates
        .map((url) => url.replaceAll(RegExp(r'/$'), ''))
        .toSet()
        .toList();
  }

  /// Chỉ cho phép các thao tác tạo/tối ưu lịch chạy trên backend đã có bộ luật
  /// thời tiết mới. Thiết bị Android thật dùng 127.0.0.1 qua adb reverse;
  /// emulator tiếp tục dùng 10.0.2.2.
  static Future<void> requireDynamicAiBackend({
    bool requireAutoWeather = false,
  }) async {
    for (final url in _candidateBackendUrls) {
      try {
        final response = await http
            .get(Uri.parse('$url/mobile/ai/capabilities'))
            .timeout(const Duration(milliseconds: 1800));
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        final features = decoded is Map ? decoded['features'] : null;
        if (decoded is Map &&
            ((decoded['apiVersion'] as num?)?.toInt() ?? 0) >= 2 &&
            features is Map &&
            features['generatedWeatherMatrix'] == true &&
            features['replacementProposals'] == true &&
            (!requireAutoWeather ||
                (features['backgroundAutoWeatherOptimization'] == true &&
                    features['autoWeatherUndo'] == true))) {
          _activeBaseUrl = url;
          _lastCheckTime = DateTime.now();
          debugPrint(
            '[ApiClient] Đã chọn backend hỗ trợ tối ưu thời tiết: $url',
          );
          return;
        }
      } catch (_) {
        // Thử địa chỉ tiếp theo.
      }
    }
    throw Exception(
      'Backend đang chạy phiên bản cũ hoặc thiết bị chưa kết nối được backend local${requireAutoWeather ? ' có cập nhật thời tiết tự động' : ''}. '
      'Hãy khởi động backend mới; với Android thật cần bật adb reverse tcp:3000 tcp:3000.',
    );
  }

  /// Lấy baseUrl hiện tại (trả về ngay lập tức `_activeBaseUrl` hoặc `defaultLocalUrl`)
  static String get baseUrl {
    return _activeBaseUrl ?? defaultLocalUrl;
  }

  /// Kiểm tra xem Backend local có đang chạy hay không.
  /// Ưu tiên chạy local backend trước, nếu không khả dụng thì tự động chuyển sang Render Backend.
  static Future<String> getOrCheckBaseUrl({bool forceCheck = false}) async {
    final now = DateTime.now();
    // Nếu đã kiểm tra thành công trong vòng 2 phút gần đây
    if (!forceCheck && _activeBaseUrl != null && _lastCheckTime != null) {
      if (now.difference(_lastCheckTime!).inMinutes < 2) {
        return _activeBaseUrl!;
      }
    }

    if (_isChecking) {
      return baseUrl;
    }

    _isChecking = true;
    final localUrl = defaultLocalUrl;

    try {
      debugPrint('[ApiClient] Đang kiểm tra kết nối Backend cục bộ: $localUrl');
      final response = await http
          .get(Uri.parse(localUrl))
          .timeout(const Duration(milliseconds: 1500));

      // Nếu nhận được phản hồi bất kỳ từ local server -> Local Backend đang chạy
      _activeBaseUrl = localUrl;
      _lastCheckTime = DateTime.now();
      debugPrint(
        '[ApiClient] ✅ Đã kết nối Backend cục bộ thành công: $_activeBaseUrl (HTTP ${response.statusCode})',
      );
    } catch (e) {
      // Backend cục bộ không phản hồi -> Sử dụng Render Cloud Backend
      _activeBaseUrl = remoteFallbackUrl;
      _lastCheckTime = DateTime.now();
      debugPrint(
        '[ApiClient] ⚠️ Backend cục bộ không khả dụng ($e). Đã chuyển sang Render Backend: $_activeBaseUrl',
      );
    } finally {
      _isChecking = false;
    }

    return _activeBaseUrl!;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Gửi HTTP Request kèm tự động chuyển đổi (Failover) sang Render Backend nếu Local Backend gặp sự cố
  static Future<http.Response> _sendRequestWithFailover(
    Future<http.Response> Function(String currentBaseUrl) requestFn, {
    bool allowRemoteFallback = true,
  }) async {
    String currentBaseUrl = await getOrCheckBaseUrl();
    try {
      return await requestFn(currentBaseUrl);
    } catch (e) {
      // Nếu đang gọi local backend mà bị lỗi kết nối, chuyển ngay sang Render Backend & thử lại
      if (allowRemoteFallback && currentBaseUrl != remoteFallbackUrl) {
        debugPrint(
          '[ApiClient] Lỗi kết nối tới $currentBaseUrl ($e). Đang thử lại qua Render Backend ($remoteFallbackUrl)...',
        );
        _activeBaseUrl = remoteFallbackUrl;
        _lastCheckTime = DateTime.now();
        return await requestFn(remoteFallbackUrl);
      }
      rethrow;
    }
  }

  static Future<http.Response> get(
    String endpoint, {
    Map<String, String>? query,
  }) async {
    return _sendRequestWithFailover((url) async {
      final uri = Uri.parse('$url$endpoint').replace(queryParameters: query);
      final headers = await _getHeaders();
      return http.get(uri, headers: headers);
    });
  }

  static Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool allowRemoteFallback = true,
  }) async {
    return _sendRequestWithFailover((url) async {
      final uri = Uri.parse('$url$endpoint');
      final headers = await _getHeaders();
      return http.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    }, allowRemoteFallback: allowRemoteFallback);
  }

  static Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    return _sendRequestWithFailover((url) async {
      final uri = Uri.parse('$url$endpoint');
      final headers = await _getHeaders();
      return http.put(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }

  static Future<http.Response> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    return _sendRequestWithFailover((url) async {
      final uri = Uri.parse('$url$endpoint');
      final headers = await _getHeaders();
      return http.patch(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    });
  }

  static Future<http.Response> delete(String endpoint) async {
    return _sendRequestWithFailover((url) async {
      final uri = Uri.parse('$url$endpoint');
      final headers = await _getHeaders();
      return http.delete(uri, headers: headers);
    });
  }
}
