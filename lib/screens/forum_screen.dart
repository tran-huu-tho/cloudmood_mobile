import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/forum_socket_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/place_detail_bottom_sheet.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/upload_progress_dialog.dart';
import '../widgets/app_video_player_dialog.dart';

class CloudmoodForumScreen extends StatefulWidget {
  const CloudmoodForumScreen({super.key});

  @override
  State<CloudmoodForumScreen> createState() => _CloudmoodForumScreenState();
}

class _CloudmoodForumScreenState extends State<CloudmoodForumScreen> {
  final ForumSocketService _socketService = ForumSocketService();
  final List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  int _page = 1;
  bool _hasMore = true;
  bool _showNewPostBadge = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;
  bool _isTogglingLike = false;
  bool _isTogglingSave = false;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
    _setupSocket();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && _hasMore) {
          _fetchFeed(loadMore: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _socketService.removeNewPostListener(_onNewPostReceived);
    _socketService.removeFeedUpdateListener(_onFeedUpdateReceived);
    _scrollController.dispose();
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // 1. Lắng nghe cập nhật thời gian thực
  void _setupSocket() {
    _socketService.connect();
    _socketService.addNewPostListener(_onNewPostReceived);
    _socketService.addFeedUpdateListener(_onFeedUpdateReceived);
  }

  void _onNewPostReceived(Map<String, dynamic> newPost) {
    if (mounted) {
      setState(() {
        // Kiểm tra xem bài đăng đã tồn tại chưa
        final exists = _posts.any((p) => p['id'] == newPost['id']);
        if (!exists) {
          _showNewPostBadge = true;
        }
      });
    }
  }

  void _onFeedUpdateReceived(Map<String, dynamic> update) {
    if (!mounted) return;

    if (update['type'] == 'post_update') {
      final updatedPost = update['post'];
      final int? postId = int.tryParse(updatedPost['id']?.toString() ?? '');
      if (postId == null) return;
      setState(() {
        final index = _posts.indexWhere((p) => p['id'] == postId);
        if (index != -1) {
          final localIsLiked = _posts[index]['isLiked'] ?? false;
          final localIsSaved = _posts[index]['isSaved'] ?? false;
          _posts[index] = Map<String, dynamic>.from(updatedPost);
          _posts[index]['isLiked'] = localIsLiked;
          _posts[index]['isSaved'] = localIsSaved;
        }
      });
      return;
    }

    if (update['type'] == 'post_deleted') {
      final int? postId = int.tryParse(update['postId']?.toString() ?? '');
      if (postId == null) return;
      setState(() {
        _posts.removeWhere((p) => p['id'] == postId);
      });
      return;
    }

    final int? postId = int.tryParse(update['postId']?.toString() ?? '');
    if (postId == null) return;

    setState(() {
      final postIndex = _posts.indexWhere((p) => p['id'] == postId);
      if (postIndex != -1) {
        final post = _posts[postIndex];
        if (update['type'] == 'like') {
          post['_count']['likes'] = update['likeCount'];
        } else if (update['type'] == 'comment') {
          post['_count']['comments'] = update['commentCount'];
        } else if (update['type'] == 'view') {
          post['viewCount'] = update['viewCount'];
        }
      }
    });
  }

  // 2. Gọi API lấy danh sách bài viết
  Future<void> _fetchFeed({bool loadMore = false, bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _hasMore = true;
        _showNewPostBadge = false;
      });
    }

    if (!_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final queryText = _searchController.text.trim();
      final queryParams = {
        'page': _page.toString(),
        'pageSize': '10',
        if (queryText.isNotEmpty) 'query': queryText,
      };
      final response = await ApiClient.get('/forum/feed', query: queryParams);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final fetchedPosts = data
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        setState(() {
          if (refresh || !loadMore) {
            _posts.clear();
          }
          _posts.addAll(fetchedPosts);
          _isLoading = false;
          _page++;
          if (fetchedPosts.length < 10) {
            _hasMore = false;
          }
        });
      } else {
        throw Exception('Failed to load feed');
      }
    } catch (e) {
      debugPrint('Error fetching forum feed: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể kết nối máy chủ diễn đàn')),
        );
      }
    }
  }

  void _showLoginPrompt(String actionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Yêu cầu đăng nhập',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn cần đăng nhập tài khoản để thực hiện chức năng $actionName.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Để sau', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => CloudmoodLoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Đăng nhập',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Like bài viết
  Future<void> _toggleLike(Map<String, dynamic> post) async {
    if (AuthService().currentUser.value == null) {
      _showLoginPrompt('thích bài viết');
      return;
    }
    if (_isTogglingLike) return;
    _isTogglingLike = true;

    final postId = post['id'];
    final originalState = post['isLiked'];
    final originalCount = post['_count']['likes'];

    // Optimistic UI Update
    setState(() {
      post['isLiked'] = !originalState;
      post['_count']['likes'] = originalCount + (originalState ? -1 : 1);
    });

    try {
      final response = await ApiClient.post('/forum/$postId/like');
      if (response.statusCode != 200 && response.statusCode != 201) {
        // Hoàn tác nếu lỗi
        setState(() {
          post['isLiked'] = originalState;
          post['_count']['likes'] = originalCount;
        });
      }
    } catch (e) {
      setState(() {
        post['isLiked'] = originalState;
        post['_count']['likes'] = originalCount;
      });
    } finally {
      _isTogglingLike = false;
    }
  }

  // 4. Lưu bài viết
  Future<void> _toggleSave(Map<String, dynamic> post) async {
    if (AuthService().currentUser.value == null) {
      _showLoginPrompt('lưu bài viết');
      return;
    }
    if (_isTogglingSave) return;
    _isTogglingSave = true;

    final postId = post['id'];
    final originalState = post['isSaved'];

    setState(() {
      post['isSaved'] = !originalState;
    });

    try {
      final response = await ApiClient.post('/forum/$postId/save');
      if (response.statusCode != 200 && response.statusCode != 201) {
        setState(() {
          post['isSaved'] = originalState;
        });
      }
    } catch (e) {
      setState(() {
        post['isSaved'] = originalState;
      });
    } finally {
      _isTogglingSave = false;
    }
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

  void _showPlaceDetail(Map<String, dynamic> place) {
    PlaceDetailBottomSheet.show(context, place);
  }

  void _debounceSearch() {
    if (_searchTimer?.isActive ?? false) _searchTimer!.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchFeed(refresh: true);
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,

      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => _fetchFeed(refresh: true),
              color: AppTheme.primary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // ── Header & Search Bar ─────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Row(
                        children: [
                          // Search bar
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withAlpha(10),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    color: AppTheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      style: TextStyle(color: AppTheme.darkText, fontSize: 13.5),
                                      decoration: const InputDecoration(
                                        hintText: 'Tìm bài viết, địa điểm...',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        focusedErrorBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                        filled: false,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 2,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        setState(() {});
                                        _debounceSearch();
                                      },
                                    ),
                                  ),
                                  if (_searchController.text.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        setState(() {});
                                        _fetchFeed(refresh: true);
                                      },
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: AppTheme.subtitleText,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Post Button
                          GestureDetector(
                            onTap: () async {
                              if (AuthService().currentUser.value == null) {
                                _showLoginPrompt('đăng bài viết');
                                return;
                              }
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const CreatePostScreen(),
                                ),
                              );
                              if (result == true) {
                                _fetchFeed(refresh: true);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10.5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Đăng bài',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Posts List ──────────────────────────────────────────
                  if (_posts.isEmpty && !_isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Chưa có bài đăng nào.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index >= _posts.length) {
                          if (_hasMore) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primary,
                                ),
                              ),
                            );
                          }
                          return const SizedBox(
                            height: 100,
                          ); // Khoảng trống tránh thanh điều hướng
                        }
                        return _buildPostCard(_posts[index]);
                      }, childCount: _posts.length + 1),
                    ),
                ],
              ),
            ),

            // ── New Post Badge ──────────────────────────────────────
            if (_showNewPostBadge)
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _fetchFeed(refresh: true);
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Có bài đăng mới',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openMediaViewer(String rawUrl, bool isVideo) {
    if (rawUrl.isEmpty) return;
    if (isVideo) {
      AppVideoPlayerDialog.show(context, rawUrl);
    } else {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  rawUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildMediaItem(
    Map<String, dynamic> item, {
    double? height,
    double? width,
    BoxFit fit = BoxFit.cover,
  }) {
    final String rawUrl = (item['url'] ?? '').toString();
    final String mType = (item['mediaType'] ?? '').toString().toLowerCase();
    final bool isVideo =
        mType == 'video' ||
        rawUrl.toLowerCase().endsWith('.mp4') ||
        rawUrl.toLowerCase().endsWith('.mov') ||
        rawUrl.toLowerCase().endsWith('.avi') ||
        rawUrl.toLowerCase().endsWith('.mkv') ||
        rawUrl.toLowerCase().endsWith('.webm') ||
        rawUrl.contains('/video/upload/');

    Widget childWidget;
    if (isVideo) {
      String thumbUrl = rawUrl;
      if (rawUrl.contains('/video/upload/')) {
        thumbUrl = rawUrl.replaceAll(
          RegExp(r'\.(mp4|mov|avi|mkv|webm)$', caseSensitive: false),
          '.jpg',
        );
      }

      childWidget = SizedBox(
        height: height ?? 200,
        width: width ?? double.infinity,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Image.network(
              thumbUrl,
              height: height ?? 200,
              width: width ?? double.infinity,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.black87,
                height: height ?? 200,
                width: width ?? double.infinity,
              ),
            ),
            Container(color: Colors.black26),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ],
        ),
      );
    } else {
      childWidget = Image.network(
        rawUrl,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          height: height ?? 200,
          width: width ?? double.infinity,
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openMediaViewer(rawUrl, isVideo),
      child: childWidget,
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final author = post['user'] ?? {};
    final place = post['place'];
    final media = post['media'] as List? ?? [];
    final count = post['_count'] ?? {};
    final bool isLiked = post['isLiked'] ?? false;
    final bool isSaved = post['isSaved'] ?? false;

    final currentUser = AuthService().currentUser.value;
    final bool isOwner =
        currentUser != null &&
        currentUser.id.toString() == author['id']?.toString();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    PostDetailScreen(postId: post['id'] as int),
              ),
            );
            if (result == true) {
              _fetchFeed(refresh: true);
            } else if (result is Map<String, dynamic>) {
              setState(() {
                post['isLiked'] = result['isLiked'];
                post['isSaved'] = result['isSaved'];
                post['_count']['likes'] = result['likeCount'];
                post['_count']['comments'] = result['commentCount'];
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Author Info
                Row(
                  children: [
                    AvatarImage(avatarUrl: author['avatar'], size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author['fullName'] ?? 'Người dùng',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _formatTimeAgo(post['createdAt']),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.subtitleText,
                                ),
                              ),
                              if (post['editedAt'] != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '• Đã chỉnh sửa',
                                  style: TextStyle(
                                    fontSize: 11,
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_outline_rounded,
                            color: isSaved
                                ? AppTheme.primary
                                : AppTheme.subtitleText,
                            size: 20,
                          ),
                          onPressed: () => _toggleSave(post),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        if (isOwner)
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: AppTheme.subtitleText,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editPost(post);
                              } else if (value == 'delete') {
                                _deletePost(post);
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Chỉnh sửa'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Xóa bài',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Post Content
                Text(
                  post['content'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkText,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // 3. Tagged Place
                if (place != null) ...[
                  GestureDetector(
                    onTap: () => _showPlaceDetail(place),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.place_rounded,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              place['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 4. Media Grid/Carousel
                if (media.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: media.length == 1
                        ? _buildMediaItem(
                            media[0] as Map<String, dynamic>,
                            height: 200,
                            width: double.infinity,
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1.3,
                                ),
                            itemCount: media.length > 4 ? 4 : media.length,
                            itemBuilder: (context, index) {
                              final item = media[index] as Map<String, dynamic>;
                              if (index == 3 && media.length > 4) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildMediaItem(item),
                                    Container(
                                      color: Colors.black.withOpacity(0.5),
                                      child: Center(
                                        child: Text(
                                          '+${media.length - 3}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return _buildMediaItem(item);
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. Actions Footer (Like, Comment, Views)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Like Button
                        InkWell(
                          onTap: () => _toggleLike(post),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_outline_rounded,
                                  color: isLiked
                                      ? Colors.redAccent
                                      : AppTheme.subtitleText,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${count['likes'] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isLiked
                                        ? Colors.redAccent
                                        : AppTheme.subtitleText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Comment Button
                        InkWell(
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PostDetailScreen(
                                  postId: post['id'] as int,
                                  focusCommentInput: true,
                                ),
                              ),
                            );
                            if (result is Map<String, dynamic>) {
                              setState(() {
                                post['isLiked'] = result['isLiked'];
                                post['isSaved'] = result['isSaved'];
                                post['_count']['likes'] = result['likeCount'];
                                post['_count']['comments'] =
                                    result['commentCount'];
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: AppTheme.subtitleText,
                                  size: 19,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${count['comments'] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.subtitleText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // View Count
                    Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: AppTheme.subtitleText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post['viewCount'] ?? 0} lượt xem',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtitleText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xóa bài viết',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa bài viết này không? Hành động này không thể hoàn tác và bài viết cũng sẽ biến mất khỏi mục đã lưu của người khác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Xóa',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiClient.delete('/forum/${post['id']}');
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa bài viết thành công!')),
          );
        }
        setState(() {
          _posts.removeWhere((p) => p['id'] == post['id']);
        });
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting post: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Xóa bài viết thất bại.')));
      }
    }
  }

  Future<void> _editPost(Map<String, dynamic> post) async {
    final textController = TextEditingController(text: post['content']);
    Map<String, dynamic>? selectedPlace = post['place'];
    final List<XFile> selectedEditFiles = [];
    bool clearExistingMedia = false;
    final ImagePicker picker = ImagePicker();

    final bool? updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final media = post['media'] as List? ?? [];
            final bool hasExistingMedia =
                media.isNotEmpty && !clearExistingMedia;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                20,
                16,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chỉnh sửa bài viết',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Bạn đang nghĩ gì?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: selectedPlace != null
                              ? Text(
                                  selectedPlace!['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Text(
                                  'Chưa gắn thẻ địa điểm',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                        if (selectedPlace != null)
                          IconButton(
                            icon: const Icon(
                              Icons.cancel_rounded,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setModalState(() {
                                selectedPlace = null;
                              });
                            },
                          )
                        else
                          TextButton(
                            onPressed: () async {
                              final place = await _showPlaceSearchInModal(
                                context,
                              );
                              if (place != null) {
                                setModalState(() {
                                  selectedPlace = place;
                                });
                              }
                            },
                            child: const Text('Gắn thẻ'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Quản lý hình ảnh/video cũ và mới
                    if (hasExistingMedia) ...[
                      const Text(
                        'Hình ảnh/video hiện tại:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: media.length,
                          itemBuilder: (context, idx) {
                            final mType = media[idx]['mediaType'] ?? '';
                            final url = (media[idx]['url'] ?? '')
                                .toString()
                                .toLowerCase();
                            final isVid =
                                mType == 'video' ||
                                url.endsWith('.mp4') ||
                                url.endsWith('.mov') ||
                                url.endsWith('.avi') ||
                                url.endsWith('.mkv') ||
                                url.endsWith('.webm');
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: isVid
                                    ? Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.black87,
                                        child: const Center(
                                          child: Icon(
                                            Icons.play_circle_fill_rounded,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                      )
                                    : Image.network(
                                        media[idx]['url'],
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            clearExistingMedia = true;
                          });
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                        label: const Text(
                          'Xóa ảnh/video cũ',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],

                    // Danh sách ảnh mới được chọn
                    if (selectedEditFiles.isNotEmpty) ...[
                      const Text(
                        'Ảnh/video mới chọn thêm:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedEditFiles.length,
                          itemBuilder: (context, idx) {
                            final path = selectedEditFiles[idx].path
                                .toLowerCase();
                            final mime = (selectedEditFiles[idx].mimeType ?? '')
                                .toLowerCase();
                            final isVideo =
                                mime.startsWith('video') ||
                                path.contains('video') ||
                                path.endsWith('.mp4') ||
                                path.endsWith('.mov') ||
                                path.endsWith('.avi') ||
                                path.endsWith('.mkv') ||
                                path.endsWith('.webm') ||
                                path.endsWith('.3gp');
                            return Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: isVideo
                                        ? Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.black87,
                                            child: const Center(
                                              child: Icon(
                                                Icons.play_circle_fill_rounded,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                          )
                                        : Image.file(
                                            File(selectedEditFiles[idx].path),
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    width: 60,
                                                    height: 60,
                                                    color: Colors.black87,
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons
                                                            .play_circle_fill_rounded,
                                                        color: Colors.white,
                                                        size: 28,
                                                      ),
                                                    ),
                                                  );
                                                },
                                          ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedEditFiles.removeAt(idx);
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Nút chọn thêm ảnh/video
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final List<XFile> images = await picker
                                .pickMultiImage();
                            if (images.isNotEmpty) {
                              setModalState(() {
                                clearExistingMedia =
                                    true; // Thêm ảnh mới sẽ thay thế ảnh cũ
                                selectedEditFiles.addAll(images);
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            'Thêm ảnh mới',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () async {
                            final XFile? video = await picker.pickVideo(
                              source: ImageSource.gallery,
                            );
                            if (video != null) {
                              setModalState(() {
                                clearExistingMedia =
                                    true; // Thêm video mới sẽ thay thế ảnh cũ
                                selectedEditFiles.add(video);
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.video_library_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            'Thêm video mới',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final contentText = textController.text.trim();
                          if (contentText.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nội dung không được để trống'),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Lưu thay đổi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (updated != true) return;

    final progressNotifier = ValueNotifier<double>(0.0);
    final statusNotifier = ValueNotifier<String>('Đang tải lên thay đổi...');
    showUploadProgressDialog(
      context,
      progressNotifier: progressNotifier,
      statusNotifier: statusNotifier,
    );

    try {
      final uri = Uri.parse('${ApiClient.baseUrl}/forum/${post['id']}');
      final request = ProgressMultipartRequest(
        'PATCH',
        uri,
        onProgress: (bytes, total) {
          if (total > 0) {
            final p = bytes / total;
            progressNotifier.value = p;
            if (p >= 0.99) {
              statusNotifier.value = 'Đang xử lý & lưu tệp...';
            }
          }
        },
      );

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['content'] = textController.text.trim();
      if (selectedPlace != null) {
        request.fields['placeId'] = selectedPlace!['id'].toString();
      } else {
        request.fields['placeId'] = 'null';
      }

      if (clearExistingMedia) {
        request.fields['clearMedia'] = 'true';
      }

      // Add selected files
      for (var file in selectedEditFiles) {
        final multipartFile = await http.MultipartFile.fromPath(
          'media',
          file.path,
          filename: file.name,
        );
        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật bài viết!')),
          );
        }
        final Map<String, dynamic> updatedPost = jsonDecode(response.body);
        setState(() {
          final index = _posts.indexWhere((p) => p['id'] == post['id']);
          if (index != -1) {
            final localIsLiked = _posts[index]['isLiked'] ?? false;
            final localIsSaved = _posts[index]['isSaved'] ?? false;
            _posts[index] = Map<String, dynamic>.from(updatedPost);
            _posts[index]['isLiked'] = localIsLiked;
            _posts[index]['isSaved'] = localIsSaved;
          }
        });
      } else {
        String errorMsg = 'Cập nhật bài viết thất bại.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMsg = errorData['message'].toString();
          }
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMsg)));
        }
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) Navigator.pop(context);
      debugPrint('Error updating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật bài viết thất bại.')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showPlaceSearchInModal(
    BuildContext parentContext,
  ) async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool isSearching = false;

    return showDialog<Map<String, dynamic>>(
      context: parentContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Tìm kiếm địa điểm',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Nhập tên địa điểm...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => searchController.clear(),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (val) async {
                        if (val.trim().isEmpty) {
                          setDialogState(() {
                            results.clear();
                          });
                          return;
                        }
                        setDialogState(() {
                          isSearching = true;
                        });
                        try {
                          final response = await ApiClient.get(
                            '/places',
                            query: {'query': val.trim(), 'limit': '5'},
                          );
                          if (response.statusCode == 200) {
                            final List<dynamic> data = jsonDecode(
                              response.body,
                            );
                            setDialogState(() {
                              results = data
                                  .map((e) => Map<String, dynamic>.from(e))
                                  .toList();
                              isSearching = false;
                            });
                          } else {
                            setDialogState(() {
                              isSearching = false;
                            });
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSearching = false;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: isSearching
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primary,
                              ),
                            )
                          : results.isEmpty
                          ? Center(
                              child: Text(
                                searchController.text.isEmpty
                                    ? 'Nhập từ khóa để tìm'
                                    : 'Không tìm thấy địa điểm',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, idx) {
                                final p = results[idx];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.place,
                                    color: AppTheme.primary,
                                  ),
                                  title: Text(
                                    p['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    p['address'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onTap: () => Navigator.pop(context, p),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
