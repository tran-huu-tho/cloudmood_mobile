import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
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
      return 'http://127.0.0.1:3000';
    }
    return 'http://localhost:3000';
  }

  static String? _activeBaseUrl;
  static DateTime? _lastCheckTime;
  static bool _isChecking = false;

  static List<String> get _candidateBackendUrls {
    final candidates = <String>[
      ?_activeBaseUrl,
      if (configuredLocalUrl.trim().isNotEmpty) configuredLocalUrl.trim(),
      'http://localhost:3000',
      'http://127.0.0.1:3000',
      if (defaultTargetPlatform == TargetPlatform.android)
        'http://10.0.2.2:3000',
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
            features['replacementProposals'] == true) {
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
    _activeBaseUrl = defaultLocalUrl;
  }

  /// Lấy baseUrl hiện tại (trả về ngay lập tức `_activeBaseUrl` hoặc `defaultLocalUrl`)
  static String get baseUrl {
    return _activeBaseUrl ?? defaultLocalUrl;
  }

  /// Kiểm tra xem Backend local có đang chạy hay không.
  static Future<String> getOrCheckBaseUrl({bool forceCheck = false}) async {
    final now = DateTime.now();
    if (!forceCheck &&
        _activeBaseUrl != null &&
        _lastCheckTime != null) {
      if (now.difference(_lastCheckTime!).inMinutes < 2) {
        return _activeBaseUrl!;
      }
    }

    if (_isChecking) {
      while (_isChecking) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return baseUrl;
    }

    _isChecking = true;
    final localCandidates = _candidateBackendUrls;

    try {
      for (final localUrl in localCandidates) {
        try {
          debugPrint(
            '[ApiClient] Đang kiểm tra kết nối Backend cục bộ: $localUrl',
          );
          final response = await http
              .get(Uri.parse(localUrl))
              .timeout(const Duration(milliseconds: 1500));
          if (response.statusCode == 200 || response.statusCode == 404) {
            _activeBaseUrl = localUrl;
            _lastCheckTime = DateTime.now();
            debugPrint(
              '[ApiClient] ✅ Đã kết nối Backend cục bộ thành công: $_activeBaseUrl (HTTP ${response.statusCode})',
            );
            return _activeBaseUrl!;
          }
        } catch (error) {
          debugPrint('[ApiClient] Backend $localUrl không khả dụng: $error');
        }
      }

      _activeBaseUrl = defaultLocalUrl;
      _lastCheckTime = DateTime.now();
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

  /// Gửi HTTP Request tới Local Backend
  static Future<http.Response> _sendRequestWithFailover(
    Future<http.Response> Function(String currentBaseUrl) requestFn, {
    bool allowRemoteFallback = true,
  }) async {
    String currentBaseUrl = await getOrCheckBaseUrl();
    return await requestFn(currentBaseUrl);
  }

  static Future<http.Response> get(
    String endpoint, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    return _sendRequestWithFailover((url) async {
      final uri = Uri.parse('$url$endpoint').replace(queryParameters: query);
      final headers = await _getHeaders();
      final request = http.get(uri, headers: headers);
      return timeout == null ? request : request.timeout(timeout);
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
