import 'dart:convert';
import 'dart:async';
import 'package:cloudmood_mobile/services/api_client.dart';
import 'package:http/http.dart' as http;

class ChatMessage {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      sessionId: json['sessionId']?.toString() ?? '',
      role: json['role'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class ChatSession {
  final String id;
  final String title;
  final String destination;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.destination,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      destination: json['destination'] ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class AITripConfig {
  final String destination;
  final int days;
  final String companions;
  final List<String> categories;
  final String pace;
  final String budget;
  final String currency;

  AITripConfig({
    required this.destination,
    required this.days,
    required this.companions,
    required this.categories,
    required this.pace,
    required this.budget,
    this.currency = 'VND',
  });

  Map<String, dynamic> toJson() => {
        'days': days,
        'companions': companions,
        'categories': categories,
        'pace': pace,
        'budget': budget,
        'currency': currency,
      };
}

class AiService {
  static Future<List<ChatSession>> getChatSessions() async {
    try {
      final response = await ApiClient.get('/mobile/ai/chat-sessions');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((item) => ChatSession.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getChatSessions: $e');
      return [];
    }
  }

  static Future<List<ChatMessage>> getChatMessages(String sessionId) async {
    try {
      final response = await ApiClient.get(
        '/mobile/ai/chat-sessions/$sessionId/messages',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((item) => ChatMessage.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getChatMessages: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> sendChatMessage({
    String? sessionId,
    required String destination,
    required String message,
    AITripConfig? tripConfig,
  }) async {
    try {
      final response = await ApiClient.post(
        '/mobile/ai/chat',
        body: {
          if (sessionId != null) 'sessionId': sessionId,
          'destination': destination,
          'message': message,
          if (tripConfig != null) 'tripConfig': tripConfig.toJson(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      throw Exception('Failed to send message');
    } catch (e) {
      print('Error sendChatMessage: $e');
      rethrow;
    }
  }

  /// Lấy câu hỏi gợi ý thông minh dựa trên dữ liệu thực từ database
  static Future<List<String>> getSuggestions({
    required String placeName,
    String type = 'place',
  }) async {
    try {
      final response = await ApiClient.get(
        '/mobile/ai/suggestions?placeName=${Uri.encodeComponent(placeName)}&type=$type',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List).map((e) => e.toString()).toList();
        }
      }
      return _getFallbackSuggestions(placeName, type);
    } catch (e) {
      print('Error getSuggestions: $e');
      return _getFallbackSuggestions(placeName, type);
    }
  }

  /// Fallback suggestions khi API không khả dụng
  static List<String> _getFallbackSuggestions(String placeName, String type) {
    if (type == 'trip') {
      return [
        'Gợi ý lịch trình 3 ngày du lịch',
        'Ẩm thực ở đây có gì đặc biệt?',
        'Nên đi vào tháng nào đẹp nhất?',
      ];
    }
    return [
      'Nên dành bao lâu để tham quan ở đây?',
      'Có lưu ý hay mẹo gì khi ghé thăm không?',
      'Xung quanh đây có gì đáng tham quan?',
    ];
  }

  /// Stream chat: nhận response từng phần (SSE)
  static Stream<Map<String, dynamic>> streamChat({
    String? sessionId,
    required String destination,
    required String message,
    AITripConfig? tripConfig,
  }) async* {
    try {
      final baseUrl = ApiClient.baseUrl;
      final token = await ApiClient.getToken();

      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/mobile/ai/chat/stream'),
      );
      request.headers['Content-Type'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.body = jsonEncode({
        if (sessionId != null) 'sessionId': sessionId,
        'destination': destination,
        'message': message,
        if (tripConfig != null) 'tripConfig': tripConfig.toJson(),
      });

      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200 && response.statusCode != 201) {
        yield {'type': 'error', 'content': 'Lỗi kết nối server'};
        return;
      }

      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isEmpty) continue;
            try {
              final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
              yield parsed;
            } catch (_) {}
          }
        }
      }

      // Process remaining buffer
      if (buffer.startsWith('data: ')) {
        final jsonStr = buffer.substring(6).trim();
        if (jsonStr.isNotEmpty) {
          try {
            final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
            yield parsed;
          } catch (_) {}
        }
      }

      client.close();
    } catch (e) {
      print('Error streamChat: $e');
      yield {'type': 'error', 'content': 'Có lỗi xảy ra khi kết nối.'};
    }
  }
}
