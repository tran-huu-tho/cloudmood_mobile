import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';

class ItinerarySocketService {
  static final ItinerarySocketService _instance = ItinerarySocketService._internal();
  factory ItinerarySocketService() => _instance;

  io.Socket? _socket;
  bool _isConnected = false;

  final List<Function(Map<String, dynamic>)> _itineraryUpdateListeners = [];

  ItinerarySocketService._internal();

  bool get isConnected => _isConnected;

  void connect() {
    if (_socket != null && _socket!.connected) return;

    debugPrint('Đang kết nối WebSocket Itinerary tại: ${ApiClient.baseUrl}/itinerary');

    _socket = io.io(
      '${ApiClient.baseUrl}/itinerary',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Đã kết nối thành công WebSocket Itinerary!');
      _isConnected = true;
      if (_currentJoinedItineraryId != null) {
        _socket!.emit('join_itinerary', {'itineraryId': _currentJoinedItineraryId.toString()});
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('Đã ngắt kết nối WebSocket Itinerary.');
      _isConnected = false;
    });

    _socket!.on('itinerary_updated', (data) {
      debugPrint('⚡⚡⚡ Nhận sự kiện itinerary_updated từ Socket Server: $data');
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(data);
      for (var listener in _itineraryUpdateListeners) {
        listener(eventData);
      }
    });

    _socket!.on('active_members_updated', (data) {
      debugPrint('🟢 Nhận danh sách thành viên online: $data');
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(data);
      for (var listener in _activeMembersListeners) {
        listener(eventData);
      }
    });

    _socket!.on('note_typing_updated', (data) {
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(data);
      for (var listener in _noteTypingListeners) {
        listener(eventData);
      }
    });
  }

  final List<Function(Map<String, dynamic>)> _noteTypingListeners = [];

  void sendTypingNote({
    required int itineraryId,
    required int noteId,
    required String text,
    required bool isItineraryDetail,
    String? userId,
  }) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('typing_note', {
        'itineraryId': itineraryId.toString(),
        'noteId': noteId,
        'text': text,
        'isItineraryDetail': isItineraryDetail,
        'userId': userId,
      });
    }
  }

  void addNoteTypingListener(Function(Map<String, dynamic>) listener) {
    if (!_noteTypingListeners.contains(listener)) {
      _noteTypingListeners.add(listener);
    }
  }

  void removeNoteTypingListener(Function(Map<String, dynamic>) listener) {
    _noteTypingListeners.remove(listener);
  }

  final List<Function(Map<String, dynamic>)> _activeMembersListeners = [];
  int? _currentJoinedItineraryId;
  Map<String, dynamic>? _currentUser;

  void joinItinerary(int itineraryId, {Map<String, dynamic>? user}) {
    _currentJoinedItineraryId = itineraryId;
    if (user != null) _currentUser = user;
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join_itinerary', {
        'itineraryId': itineraryId.toString(),
        'user': _currentUser,
      });
      debugPrint('Đã gửi yêu cầu join_itinerary: $itineraryId với user: $_currentUser');
    }
  }

  void leaveItinerary(int itineraryId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave_itinerary', {'itineraryId': itineraryId.toString()});
    }
  }

  void addUpdateListener(Function(Map<String, dynamic>) listener) {
    if (!_itineraryUpdateListeners.contains(listener)) {
      _itineraryUpdateListeners.add(listener);
    }
  }

  void removeUpdateListener(Function(Map<String, dynamic>) listener) {
    _itineraryUpdateListeners.remove(listener);
  }

  void addActiveMembersListener(Function(Map<String, dynamic>) listener) {
    if (!_activeMembersListeners.contains(listener)) {
      _activeMembersListeners.add(listener);
    }
  }

  void removeActiveMembersListener(Function(Map<String, dynamic>) listener) {
    _activeMembersListeners.remove(listener);
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
    }
  }
}
