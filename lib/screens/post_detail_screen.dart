import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/forum_socket_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/place_detail_bottom_sheet.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  final bool focusCommentInput;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.focusCommentInput = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final ForumSocketService _socketService = ForumSocketService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSendingComment = false;
  XFile? _selectedCommentMedia;
  final ImagePicker _picker = ImagePicker();
  bool _isTogglingLike = false;
  bool _isTogglingSave = false;
  int? _editingCommentId;
  bool _clearCommentMedia = false;
  String? _editingCommentExistingMediaUrl;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    _setupSocket();

    if (widget.focusCommentInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _socketService.leavePostRoom(widget.postId);
    _socketService.removeLikeUpdateListener(_onLikeUpdateReceived);
    _socketService.removeCommentAddedListener(_onCommentAddedReceived);
    _socketService.removeCommentDeletedListener(_onCommentDeletedReceived);
    _socketService.removeCommentUpdatedListener(_onCommentUpdatedReceived);
    _socketService.removeViewUpdateListener(_onViewUpdateReceived);
    _socketService.removePostUpdateListener(_onPostUpdateReceived);
    _socketService.removePostDeletedListener(_onPostDeletedReceived);
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 1. WebSocket Setup
  void _setupSocket() {
    _socketService.connect();
    _socketService.joinPostRoom(widget.postId);
    _socketService.addLikeUpdateListener(_onLikeUpdateReceived);
    _socketService.addCommentAddedListener(_onCommentAddedReceived);
    _socketService.addCommentDeletedListener(_onCommentDeletedReceived);
    _socketService.addCommentUpdatedListener(_onCommentUpdatedReceived);
    _socketService.addViewUpdateListener(_onViewUpdateReceived);
    _socketService.addPostUpdateListener(_onPostUpdateReceived);
    _socketService.addPostDeletedListener(_onPostDeletedReceived);
  }

  void _onPostUpdateReceived(Map<String, dynamic> updatedPost) {
    if (mounted && updatedPost['id'] == widget.postId) {
      setState(() {
        if (_post != null) {
          final localIsLiked = _post!['isLiked'] ?? false;
          final localIsSaved = _post!['isSaved'] ?? false;
          _post = Map<String, dynamic>.from(updatedPost);
          _post!['isLiked'] = localIsLiked;
          _post!['isSaved'] = localIsSaved;
        }
      });
    }
  }

  void _onPostDeletedReceived(Map<String, dynamic> data) {
    if (mounted && int.tryParse(data['postId']?.toString() ?? '') == widget.postId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bài viết này đã bị xóa bởi người đăng')),
      );
      Navigator.pop(context, true); // Quay lại bảng tin và làm mới
    }
  }

  void _onLikeUpdateReceived(Map<String, dynamic> update) {
    if (!mounted) return;
    if (int.tryParse(update['postId']?.toString() ?? '') == widget.postId) {
      setState(() {
        if (_post != null) {
          _post!['_count']['likes'] = update['likeCount'];
        }
      });
    }
  }

  void _onCommentAddedReceived(Map<String, dynamic> update) {
    if (!mounted) return;
    if (int.tryParse(update['postId']?.toString() ?? '') == widget.postId) {
      final comment = Map<String, dynamic>.from(update['comment']);
      setState(() {
        // Kiểm tra xem bình luận đã tồn tại chưa (tránh trùng do tự gửi + nhận socket)
        final exists = _comments.any((c) => c['id'] == comment['id']);
        if (!exists) {
          _comments.add(comment);
        }
        if (_post != null) {
          _post!['_count']['comments'] = update['commentCount'];
        }
      });
      // Tự động cuộn xuống cuối cùng khi có bình luận mới
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _onCommentDeletedReceived(Map<String, dynamic> update) {
    if (!mounted) return;
    if (int.tryParse(update['postId']?.toString() ?? '') == widget.postId) {
      final commentId = int.tryParse(update['commentId']?.toString() ?? '');
      if (commentId == null) return;
      setState(() {
        _comments.removeWhere((c) => int.tryParse(c['id']?.toString() ?? '') == commentId);
        if (_post != null) {
          _post!['_count']['comments'] = update['commentCount'];
        }
      });
    }
  }

  void _onCommentUpdatedReceived(Map<String, dynamic> update) {
    if (!mounted) return;
    if (int.tryParse(update['postId']?.toString() ?? '') == widget.postId) {
      final updatedComment = Map<String, dynamic>.from(update['comment']);
      final commentId = int.tryParse(updatedComment['id']?.toString() ?? '');
      if (commentId == null) return;
      setState(() {
        final index = _comments.indexWhere((c) => int.tryParse(c['id']?.toString() ?? '') == commentId);
        if (index != -1) {
          _comments[index] = updatedComment;
        }
      });
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa bình luận', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn xóa bình luận này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiClient.delete('/forum/comment/$commentId');
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa bình luận')),
        );
        setState(() {
          _comments.removeWhere((c) => int.tryParse(c['id']?.toString() ?? '') == commentId);
          if (_post != null) {
            final currentCount = _post!['_count']['comments'] as int? ?? 0;
            _post!['_count']['comments'] = currentCount > 0 ? currentCount - 1 : 0;
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa bình luận này')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting comment: $e');
    }
  }

  void _onViewUpdateReceived(Map<String, dynamic> update) {
    if (!mounted) return;
    if (int.tryParse(update['postId']?.toString() ?? '') == widget.postId) {
      setState(() {
        if (_post != null) {
          _post!['viewCount'] = update['viewCount'];
        }
      });
    }
  }

  // 2. Fetch Post Details & Comments
  Future<void> _fetchDetails() async {
    try {
      final response = await ApiClient.get('/forum/${widget.postId}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _post = data;
          _comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load post');
      }
    } catch (e) {
      debugPrint('Error loading post detail: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải dữ liệu bài đăng')),
        );
      }
    }
  }

  void _showLoginPrompt(String actionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Yêu cầu đăng nhập', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn cần đăng nhập tài khoản để thực hiện chức năng $actionName.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Để sau', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CloudmoodLoginScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Đăng nhập', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 3. Like bài viết
  Future<void> _toggleLike() async {
    if (_post == null) return;
    if (AuthService().currentUser.value == null) {
      _showLoginPrompt('thích bài viết');
      return;
    }
    if (_isTogglingLike) return;
    _isTogglingLike = true;

    final originalState = _post!['isLiked'];
    final originalCount = _post!['_count']['likes'];

    setState(() {
      _post!['isLiked'] = !originalState;
      _post!['_count']['likes'] = originalCount + (originalState ? -1 : 1);
    });

    try {
      final response = await ApiClient.post('/forum/${widget.postId}/like');
      if (response.statusCode != 200 && response.statusCode != 201) {
        setState(() {
          _post!['isLiked'] = originalState;
          _post!['_count']['likes'] = originalCount;
        });
      }
    } catch (e) {
      setState(() {
        _post!['isLiked'] = originalState;
        _post!['_count']['likes'] = originalCount;
      });
    } finally {
      _isTogglingLike = false;
    }
  }

  // 4. Lưu bài viết
  Future<void> _toggleSave() async {
    if (_post == null) return;
    if (AuthService().currentUser.value == null) {
      _showLoginPrompt('lưu bài viết');
      return;
    }
    if (_isTogglingSave) return;
    _isTogglingSave = true;

    final originalState = _post!['isSaved'];

    setState(() {
      _post!['isSaved'] = !originalState;
    });

    try {
      final response = await ApiClient.post('/forum/${widget.postId}/save');
      if (response.statusCode != 200 && response.statusCode != 201) {
        setState(() {
          _post!['isSaved'] = originalState;
        });
      }
    } catch (e) {
      setState(() {
        _post!['isSaved'] = originalState;
      });
    } finally {
      _isTogglingSave = false;
    }
  }

  Future<void> _pickCommentMedia() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
              title: const Text('Chọn hình ảnh'),
              onTap: () async {
                Navigator.pop(context);
                final file = await _picker.pickImage(source: ImageSource.gallery);
                if (file != null) {
                  setState(() {
                    _selectedCommentMedia = file;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library_rounded, color: AppTheme.primary),
              title: const Text('Chọn video'),
              onTap: () async {
                Navigator.pop(context);
                final file = await _picker.pickVideo(source: ImageSource.gallery);
                if (file != null) {
                  setState(() {
                    _selectedCommentMedia = file;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startEditComment(Map<String, dynamic> comment) {
    setState(() {
      _editingCommentId = int.tryParse(comment['id']?.toString() ?? '');
      _commentController.text = comment['content'] ?? '';
      _selectedCommentMedia = null;
      _clearCommentMedia = false;
      _editingCommentExistingMediaUrl = comment['mediaUrl'];
      _commentFocusNode.requestFocus();
    });
  }

  void _cancelEditComment() {
    setState(() {
      _editingCommentId = null;
      _commentController.clear();
      _selectedCommentMedia = null;
      _clearCommentMedia = false;
      _editingCommentExistingMediaUrl = null;
      _commentFocusNode.unfocus();
    });
  }

  // 5. Gửi / Chỉnh sửa bình luận
  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    final bool isEditing = _editingCommentId != null;

    final bool hasText = content.isNotEmpty;
    final bool hasMedia = _selectedCommentMedia != null || 
        (isEditing && _editingCommentExistingMediaUrl != null && !_clearCommentMedia);

    if (!hasText && !hasMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nội dung bình luận không được để trống')),
      );
      return;
    }

    setState(() {
      _isSendingComment = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final bool isEditing = _editingCommentId != null;
      final url = isEditing
          ? '${ApiClient.baseUrl}/forum/comment/$_editingCommentId'
          : '${ApiClient.baseUrl}/forum/${widget.postId}/comment';

      final request = http.MultipartRequest(isEditing ? 'PATCH' : 'POST', Uri.parse(url));

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['content'] = content;
      if (isEditing) {
        request.fields['clearMedia'] = _clearCommentMedia.toString();
      }

      if (_selectedCommentMedia != null) {
        final multipartFile = await http.MultipartFile.fromPath('media', _selectedCommentMedia!.path);
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _commentController.clear();
        setState(() {
          _selectedCommentMedia = null;
          _editingCommentId = null;
          _clearCommentMedia = false;
          _editingCommentExistingMediaUrl = null;
        });
        _commentFocusNode.unfocus();
        _fetchDetails();
      }
    } catch (e) {
      debugPrint('Error sending/editing comment: $e');
    } finally {
      setState(() {
        _isSendingComment = false;
      });
    }
  }

  void _showPlaceDetail(Map<String, dynamic> place) {
    PlaceDetailBottomSheet.show(context, place);
  }

  String _formatTimeAgo(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (diff.inDays >= 1) {
        return '${diff.inDays} ngày trước';
      } else if (diff.inHours >= 1) {
        return '${diff.inHours} giờ trước';
      } else if (diff.inMinutes >= 1) {
        return '${diff.inMinutes} phút trước';
      }
      return 'Vừa xong';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết')),
        body: const Center(child: Text('Bài viết không tồn tại')),
      );
    }

    final author = _post!['user'] ?? {};
    final place = _post!['place'];
    final media = _post!['media'] as List? ?? [];
    final count = _post!['_count'] ?? {};
    final bool isLiked = _post!['isLiked'] ?? false;
    final bool isSaved = _post!['isSaved'] ?? false;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_post != null) {
          Navigator.pop(context, {
            'isLiked': _post!['isLiked'],
            'isSaved': _post!['isSaved'],
            'likeCount': _post!['_count']['likes'],
            'commentCount': _comments.length,
          });
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (_post != null) {
                Navigator.pop(context, {
                  'isLiked': _post!['isLiked'],
                  'isSaved': _post!['isSaved'],
                  'likeCount': _post!['_count']['likes'],
                  'commentCount': _comments.length,
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text('Bài viết', style: TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w800, fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: IconThemeData(color: AppTheme.darkText),
          actions: [
            IconButton(
              icon: Icon(
                isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                color: isSaved ? AppTheme.primary : AppTheme.darkText,
              ),
              onPressed: _toggleSave,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Author row
                  Row(
                    children: [
                      AvatarImage(
                        avatarUrl: author['avatar'],
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              author['fullName'] ?? 'Người dùng',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  _formatTimeAgo(_post!['createdAt']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.subtitleText,
                                  ),
                                ),
                                if (_post!['editedAt'] != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '• Đã chỉnh sửa',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.subtitleText,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Post Content
                  Text(
                    _post!['content'] ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.darkText,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Tagged Place
                  if (place != null) ...[
                    GestureDetector(
                      onTap: () => _showPlaceDetail(place),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.place_rounded, size: 18, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    place['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  if (place['address'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      place['address'] ?? '',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. Media Files List
                  if (media.isNotEmpty) ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: media.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              media[index]['url'],
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: Colors.grey[200], height: 200, child: const Icon(Icons.broken_image)),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 5. Actions row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: _toggleLike,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                                    color: isLiked ? Colors.redAccent : AppTheme.subtitleText,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${count['likes'] ?? 0} thích',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isLiked ? Colors.redAccent : AppTheme.subtitleText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 20, color: AppTheme.subtitleText),
                              const SizedBox(width: 8),
                              Text(
                                '${count['comments'] ?? 0} bình luận',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.subtitleText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 18, color: AppTheme.subtitleText),
                          const SizedBox(width: 6),
                          Text(
                            '${_post!['viewCount'] ?? 0} lượt xem',
                            style: TextStyle(fontSize: 13, color: AppTheme.subtitleText),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 32, thickness: 1, color: Color(0xFFF1F5F9)),

                  // 6. Comments list
                  Text(
                    'Bình luận',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 12),
                  if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Chưa có bình luận nào. Hãy là người đầu tiên!',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final cAuthor = comment['user'] ?? {};
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AvatarImage(avatarUrl: cAuthor['avatar'], size: 32),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              cAuthor['fullName'] ?? 'Người dùng',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.darkText,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatTimeAgo(comment['createdAt']),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (AuthService().currentUser.value != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Sửa bình luận - Chỉ chủ nhân bình luận
                                              if (comment['userId']?.toString() == AuthService().currentUser.value!.id.toString()) ...[
                                                GestureDetector(
                                                  onTap: () => _startEditComment(comment),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                    child: Icon(
                                                      Icons.edit_outlined,
                                                      size: 16,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                              ],
                                              // Xóa bình luận - Chủ bình luận HOẶC chủ bài viết
                                              if (comment['userId']?.toString() == AuthService().currentUser.value!.id.toString() ||
                                                  _post?['userId']?.toString() == AuthService().currentUser.value!.id.toString())
                                                GestureDetector(
                                                  onTap: () {
                                                    final int? commentId = int.tryParse(comment['id']?.toString() ?? '');
                                                    if (commentId != null) {
                                                      _deleteComment(commentId);
                                                    }
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                    child: Icon(
                                                      Icons.delete_outline_rounded,
                                                      size: 16,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      comment['content'] ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[800],
                                        height: 1.3,
                                      ),
                                    ),
                                    if (comment['mediaUrl'] != null) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Image.network(
                                              comment['mediaUrl'],
                                              height: 120,
                                              width: 160,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  Container(
                                                    color: Colors.grey[200],
                                                    width: 160,
                                                    height: 100,
                                                    child: const Icon(Icons.broken_image, size: 20),
                                                  ),
                                            ),
                                            if (comment['mediaType'] == 'VIDEO')
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 80), // Chừa khoảng trống để tránh đè lên ô nhập
                ],
              ),
            ),
          ),

          // 7. Write Comment Box
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner khi đang sửa bình luận
                if (_editingCommentId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Đang chỉnh sửa bình luận...',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: _cancelEditComment,
                          child: const Icon(
                            Icons.cancel_rounded,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Preview selected media
                if (_selectedCommentMedia != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    height: 80,
                    width: 80,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _selectedCommentMedia!.path.endsWith('.mp4') || _selectedCommentMedia!.path.endsWith('.mov')
                              ? Container(
                                  color: Colors.black87,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.videocam_rounded, color: Colors.white),
                                )
                              : Image.file(
                                  File(_selectedCommentMedia!.path),
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCommentMedia = null;
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_editingCommentExistingMediaUrl != null && !_clearCommentMedia) ...[
                  // Preview hình ảnh bình luận cũ đang sửa
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    height: 80,
                    width: 80,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _editingCommentExistingMediaUrl!,
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 20)),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _clearCommentMedia = true;
                              });
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  children: [
                    if (AuthService().currentUser.value != null) ...[
                      IconButton(
                        icon: Icon(Icons.attach_file_rounded, color: AppTheme.subtitleText),
                        onPressed: _pickCommentMedia,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: AuthService().currentUser.value == null
                            ? GestureDetector(
                                onTap: () => _showLoginPrompt('bình luận'),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'Đăng nhập để bình luận...',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            : TextField(
                                controller: _commentController,
                                focusNode: _commentFocusNode,
                                decoration: InputDecoration(
                                  hintText: _editingCommentId != null
                                      ? 'Chỉnh sửa bình luận của bạn...'
                                      : 'Nhập bình luận của bạn...',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                maxLines: null,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AuthService().currentUser.value == null
                        ? IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.grey),
                            onPressed: () => _showLoginPrompt('bình luận'),
                          )
                        : _isSendingComment
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                            : IconButton(
                                icon: Icon(
                                  _editingCommentId != null ? Icons.check_rounded : Icons.send_rounded,
                                  color: AppTheme.primary,
                                ),
                                onPressed: _sendComment,
                              ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
