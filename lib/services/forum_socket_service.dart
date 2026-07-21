import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';

class ForumSocketService {
  static final ForumSocketService _instance = ForumSocketService._internal();
  factory ForumSocketService() => _instance;

  io.Socket? _socket;
  bool _isConnected = false;

  // Listeners
  final List<Function(Map<String, dynamic>)> _newPostListeners = [];
  final List<Function(Map<String, dynamic>)> _likeUpdateListeners = [];
  final List<Function(Map<String, dynamic>)> _commentAddedListeners = [];
  final List<Function(Map<String, dynamic>)> _viewUpdateListeners = [];
  final List<Function(Map<String, dynamic>)> _feedUpdateListeners = [];
  final List<Function(Map<String, dynamic>)> _postUpdateListeners = [];
  final List<Function(Map<String, dynamic>)> _postDeletedListeners = [];
  final List<Function(Map<String, dynamic>)> _commentDeletedListeners = [];
  final List<Function(Map<String, dynamic>)> _commentUpdatedListeners = [];

  ForumSocketService._internal();

  bool get isConnected => _isConnected;

  // 1. Kết nối đến WebSocket Gateway
  void connect() {
    if (_socket != null && _socket!.connected) return;

    debugPrint('Đang kết nối đến WebSocket Diễn đàn tại: ${ApiClient.baseUrl}/forum');
    
    _socket = io.io(
      '${ApiClient.baseUrl}/forum',
      io.OptionBuilder()
          .setTransports(['websocket']) // Bắt buộc sử dụng websocket transport
          .enableAutoConnect()
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Đã kết nối thành công đến WebSocket Diễn đàn!');
      _isConnected = true;
    });

    _socket!.onDisconnect((_) {
      debugPrint('Đã ngắt kết nối WebSocket Diễn đàn.');
      _isConnected = false;
    });

    _socket!.onConnectError((err) {
      debugPrint('Lỗi kết nối WebSocket Diễn đàn: $err');
    });

    // Lắng nghe các sự kiện từ Server
    _socket!.on('new_post', (data) {
      debugPrint('Nhận sự kiện new_post: $data');
      final Map<String, dynamic> post = Map<String, dynamic>.from(data);
      for (var listener in _newPostListeners) {
        listener(post);
      }
    });

    _socket!.on('like_update', (data) {
      debugPrint('Nhận sự kiện like_update: $data');
      final Map<String, dynamic> update = Map<String, dynamic>.from(data);
      for (var listener in _likeUpdateListeners) {
        listener(update);
      }
    });

    _socket!.on('new_comment', (data) {
      debugPrint('Nhận sự kiện new_comment: $data');
      final Map<String, dynamic> update = Map<String, dynamic>.from(data);
      for (var listener in _commentAddedListeners) {
        listener(update);
      }
    });

    _socket!.on('comment_deleted', (data) {
      debugPrint('Nhận sự kiện comment_deleted: $data');
      final Map<String, dynamic> update = Map<String, dynamic>.from(data);
      for (var listener in _commentDeletedListeners) {
        listener(update);
      }
    });

    _socket!.on('comment_updated', (data) {
      debugPrint('Nhận sự kiện comment_updated: $data');
      final Map<String, dynamic> update = Map<String, dynamic>.from(data);
      for (var listener in _commentUpdatedListeners) {
        listener(update);
      }
    });

    _socket!.on('view_update', (data) {
      debugPrint('Nhận sự kiện view_update: $data');
      final Map<String, dynamic> update = Map<String, dynamic>.from(data);
      for (var listener in _viewUpdateListeners) {
        listener(update);
      }
    });

    _socket!.on('post_update', (data) {
      debugPrint('Nhận sự kiện post_update: $data');
      final Map<String, dynamic> update = Map<String, dynamic>.from(data);
      for (var listener in _postUpdateListeners) {
        listener(update);
      }
    });

    _socket!.on('post_deleted', (data) {
      debugPrint('Nhận sự kiện post_deleted: $data');
      final Map<String, dynamic> update = Map<String, dynamic>.from(data);
      for (var listener in _postDeletedListeners) {
        listener(update);
      }
    });

    // Lắng nghe các sự kiện cập nhật feed chung
    _socket!.on('feed_like_update', (data) {
      final Map<String, dynamic> update = Map<String, dynamic>.from(data);
      for (var listener in _feedUpdateListeners) {
        listener({'type': 'like', ...update});
      }
    });

    _socket!.on('feed_comment_update', (data) {
      final Map<String, dynamic> update = Map<String, dynamic>.from(data);
      for (var listener in _feedUpdateListeners) {
        listener({'type': 'comment', ...update});
      }
    });

    _socket!.on('feed_view_update', (data) {
      final Map<String, dynamic> update = Map<String, dynamic>.from(data);
      for (var listener in _feedUpdateListeners) {
        listener({'type': 'view', ...update});
      }
    });

    _socket!.on('feed_post_update', (data) {
      final Map<String, dynamic> update = Map<String, dynamic>.from(data);
      for (var listener in _feedUpdateListeners) {
        listener({'type': 'post_update', 'post': update});
      }
    });

    _socket!.on('feed_post_deleted', (data) {
      final Map<String, dynamic> update = Map<String, dynamic>.from(data);
      for (var listener in _feedUpdateListeners) {
        listener({'type': 'post_deleted', ...update});
      }
    });
  }

  // 2. Ngắt kết nối
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
      debugPrint('Đã hủy kết nối socket diễn đàn.');
    }
  }

  // 3. Tham gia vào phòng của một bài viết cụ thể
  void joinPostRoom(int postId) {
    if (_socket == null || !_socket!.connected) return;
    debugPrint('Gửi yêu cầu join_post: $postId');
    _socket!.emit('join_post', {'postId': postId.toString()});
  }

  // 4. Rời phòng của bài viết
  void leavePostRoom(int postId) {
    if (_socket == null || !_socket!.connected) return;
    debugPrint('Gửi yêu cầu leave_post: $postId');
    _socket!.emit('leave_post', {'postId': postId.toString()});
  }

  // 5. Đăng ký người nghe sự kiện
  void addNewPostListener(Function(Map<String, dynamic>) listener) {
    _newPostListeners.add(listener);
  }

  void removeNewPostListener(Function(Map<String, dynamic>) listener) {
    _newPostListeners.remove(listener);
  }

  void addLikeUpdateListener(Function(Map<String, dynamic>) listener) {
    _likeUpdateListeners.add(listener);
  }

  void removeLikeUpdateListener(Function(Map<String, dynamic>) listener) {
    _likeUpdateListeners.remove(listener);
  }

  void addCommentAddedListener(Function(Map<String, dynamic>) listener) {
    _commentAddedListeners.add(listener);
  }

  void removeCommentAddedListener(Function(Map<String, dynamic>) listener) {
    _commentAddedListeners.remove(listener);
  }

  void addCommentDeletedListener(Function(Map<String, dynamic>) listener) {
    _commentDeletedListeners.add(listener);
  }

  void removeCommentDeletedListener(Function(Map<String, dynamic>) listener) {
    _commentDeletedListeners.remove(listener);
  }

  void addCommentUpdatedListener(Function(Map<String, dynamic>) listener) {
    _commentUpdatedListeners.add(listener);
  }

  void removeCommentUpdatedListener(Function(Map<String, dynamic>) listener) {
    _commentUpdatedListeners.remove(listener);
  }

  void addViewUpdateListener(Function(Map<String, dynamic>) listener) {
    _viewUpdateListeners.add(listener);
  }

  void removeViewUpdateListener(Function(Map<String, dynamic>) listener) {
    _viewUpdateListeners.remove(listener);
  }

  void addFeedUpdateListener(Function(Map<String, dynamic>) listener) {
    _feedUpdateListeners.add(listener);
  }

  void removeFeedUpdateListener(Function(Map<String, dynamic>) listener) {
    _feedUpdateListeners.remove(listener);
  }

  void addPostUpdateListener(Function(Map<String, dynamic>) listener) {
    _postUpdateListeners.add(listener);
  }

  void removePostUpdateListener(Function(Map<String, dynamic>) listener) {
    _postUpdateListeners.remove(listener);
  }

  void addPostDeletedListener(Function(Map<String, dynamic>) listener) {
    _postDeletedListeners.add(listener);
  }

  void removePostDeletedListener(Function(Map<String, dynamic>) listener) {
    _postDeletedListeners.remove(listener);
  }
}
