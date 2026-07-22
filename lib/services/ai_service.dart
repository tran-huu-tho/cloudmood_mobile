import 'dart:convert';
import 'package:cloudmood_mobile/services/api_client.dart';

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
  }) async {
    try {
      final response = await ApiClient.post(
        '/mobile/ai/chat',
        body: {
          if (sessionId != null) 'sessionId': sessionId,
          'destination': destination,
          'message': message,
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
}
