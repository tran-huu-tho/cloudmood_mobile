import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../widgets/explore_post_card.dart';
import 'explore_post_detail_screen.dart';

class AllExploreGuidesScreen extends StatefulWidget {
  const AllExploreGuidesScreen({super.key});

  @override
  State<AllExploreGuidesScreen> createState() => _AllExploreGuidesScreenState();
}

class _AllExploreGuidesScreenState extends State<AllExploreGuidesScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await DatabaseService().fetchExplorePosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPosts = _posts.where((post) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final title = (post['title'] ?? '').toString().toLowerCase();
      final desc = (post['description'] ?? post['content'] ?? '').toString().toLowerCase();
      final authorName = (post['user']?['name'] ?? post['author']?['name'] ?? '').toString().toLowerCase();
      bool matchesPlace = false;
      if (post['items'] is List) {
        for (var item in (post['items'] as List)) {
          final pName = (item['place']?['name'] ?? '').toString().toLowerCase();
          if (pName.contains(q)) {
            matchesPlace = true;
            break;
          }
        }
      }
      return title.contains(q) || desc.contains(q) || authorName.contains(q) || matchesPlace;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Hướng dẫn & Cẩm nang du lịch',
          style: TextStyle(
            color: AppTheme.darkText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'SDK_SC_Web-Heavy',
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Pill Box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm cẩm nang, điểm đến...',
                        hintStyle: TextStyle(color: AppTheme.subtitleText, fontSize: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: TextStyle(color: AppTheme.darkText, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                      child: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                    ),
                ],
              ),
            ),
          ),

          // Posts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : RefreshIndicator(
                    onRefresh: _fetchPosts,
                    color: AppTheme.primary,
                    child: filteredPosts.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 40),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryContainer.withAlpha(80),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.explore_off_rounded,
                                      size: 40,
                                      color: AppTheme.primary.withAlpha(180),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty ? 'Không tìm thấy cẩm nang phù hợp' : 'Chưa có cẩm nang du lịch nào',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText, fontFamily: 'SDK_SC_Web-Heavy'),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _searchQuery.isNotEmpty ? 'Thử tìm kiếm với từ khóa khác xem sao nhé!' : 'Các bài viết kinh nghiệm sẽ được cập nhật sớm nhất!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: AppTheme.subtitleText),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: filteredPosts.length,
                            itemBuilder: (context, index) {
                              final post = filteredPosts[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: ExplorePostCard(
                                  post: post,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ExplorePostDetailScreen(
                                          postId: post['id'] as int,
                                          title: post['title'] ?? 'Chi tiết',
                                        ),
                                      ),
                                    ).then((_) => _fetchPosts());
                                  },
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
