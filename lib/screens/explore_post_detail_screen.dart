import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'explore_post_map_screen.dart';
import '../utils/time_utils.dart';
import '../widgets/expandable_opening_hours.dart';
class ExplorePostDetailScreen extends StatefulWidget {
  final int postId;
  final String title;

  const ExplorePostDetailScreen({
    Key? key,
    required this.postId,
    required this.title,
  }) : super(key: key);

  @override
  _ExplorePostDetailScreenState createState() => _ExplorePostDetailScreenState();
}

class _ExplorePostDetailScreenState extends State<ExplorePostDetailScreen> {
  Map<String, dynamic>? _post;
  bool _isLoading = true;
  final Set<int> _expandedPlaces = {};

  @override
  void initState() {
    super.initState();
    _fetchPostDetail();
  }

  Future<void> _fetchPostDetail() async {
    try {
      // Giả định backend chạy ở localhost:3000
      final response = await http.get(Uri.parse('http://localhost:3000/explore/${widget.postId}'));
      if (response.statusCode == 200) {
        setState(() {
          _post = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching post details: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildReviewStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 14);
        } else if (index < rating && (rating - rating.floor()) >= 0.5) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 14);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 14);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lỗi')),
        body: const Center(child: Text('Không tìm thấy bài viết')),
      );
    }

    final coverImage = _post!['coverImage'] ?? 'https://via.placeholder.com/800x400';
    final title = _post!['title'] ?? '';
    final description = _post!['description'] ?? '';
    
    final isPlatform = _post!['postType'] == 'PLATFORM_CURATION';
    final platformName = _post!['platformName'] ?? '';
    final platformLogo = _post!['platformLogo'] ?? '';
    
    final authorName = isPlatform 
        ? platformName 
        : (_post!['author']?['fullName'] ?? 'Người dùng Ẩn danh');
    
    final avatarUrl = isPlatform 
        ? platformLogo 
        : (_post!['author']?['avatar'] ?? 'https://via.placeholder.com/150');

    final items = _post!['items'] as List? ?? [];

    int placeCounter = 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Header with Cover Image and Overlaid Title
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_circle_down),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3.0,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    coverImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
                  ),
                  // Gradient for better text readability
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Platform / Author Info Row
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[200],
                    child: isPlatform 
                        ? const Text('G', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                        : null,
                    backgroundImage: !isPlatform ? NetworkImage(avatarUrl) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isPlatform ? 'Từ $authorName' : authorName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontStyle: isPlatform ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                  if (isPlatform)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Mở bài viết',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Description
          if (description.isNotEmpty && !isPlatform)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          
          // List of Places/Items
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  final itemType = item['itemType'];
                  
                  if (itemType == 'PLACE') {
                    final place = item['place'];
                    if (place == null) return const SizedBox();
                    
                    final placeName = place['name'] ?? '';
                    final placeImage = place['image'] ?? 'https://via.placeholder.com/300x200';
                    final category = place['category']?['name'] ?? 'Địa điểm';
                    final featuredReview = item['featuredReview'];
                    final content = item['content'] ?? '';
                    
                    final currentIndex = placeCounter++;
                    int currentReviewIndex = 0;

                    final isExpanded = _expandedPlaces.contains(currentIndex);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedPlaces.remove(currentIndex);
                          } else {
                            _expandedPlaces.add(currentIndex);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Index circle, Name, Thêm button
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFFE53935),
                                  child: Text(
                                    '$currentIndex',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    placeName,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E2C),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.bookmark_border, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Thêm', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Tags
                            Builder(
                              builder: (context) {
                                final hoursText = TimeUtils.getOpeningHoursText(place['openingHours']);
                                final isClosed = hoursText.toLowerCase().contains('đóng cửa');
                                
                                return Row(
                                  children: [
                                    if (isClosed) ...[
                                      Flexible(child: _buildTag('Tạm đóng cửa', isRed: true)),
                                      const SizedBox(width: 6),
                                    ],
                                    Flexible(child: _buildTag(category)),
                                    if ((place['subCategories'] as List?)?.isNotEmpty == true) ...[
                                      const SizedBox(width: 6),
                                      Flexible(child: _buildTag(_getSubCategoryText((place['subCategories'] as List).first))),
                                    ],
                                  ],
                                );
                              }
                            ),
                            const SizedBox(height: 16),
                            
                            // Description and Image
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    content.isNotEmpty ? content : (place['description']?.toString().isNotEmpty == true ? place['description'] : 'Đang cập nhật thông tin...'),
                                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    placeImage,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(width: 70, height: 70, color: Colors.grey[200]),
                                  ),
                                ),
                              ],
                            ),
                            
                            // Expanded Details
                            if (isExpanded) ...[
                              const SizedBox(height: 16),
                              if ((place['reviews'] as List?)?.isNotEmpty == true)
                                StatefulBuilder(
                                  builder: (context, setLocalState) {
                                    final reviews = place['reviews'] as List;
                                    final maxDots = reviews.length > 5 ? 5 : reviews.length;

                                    return Column(
                                      children: [
                                        SizedBox(
                                          height: 150, // Fixed height for page view
                                          child: PageView.builder(
                                            controller: PageController(viewportFraction: 1.0),
                                            onPageChanged: (idx) {
                                              setLocalState(() {
                                                currentReviewIndex = idx;
                                              });
                                            },
                                            itemCount: reviews.length,
                                            itemBuilder: (context, idx) {
                                              final review = reviews[idx];
                                              return Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('“', style: TextStyle(fontSize: 40, color: Color(0xFFDCDCDC), height: 1.1, fontWeight: FontWeight.bold)),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          review['comment'] ?? '',
                                                          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                                                          maxLines: 4,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 8),
                                                        _buildReviewStars((review['rating'] ?? 5).toDouble()),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          '${review['authorName'] ?? 'Người dùng'} — đánh giá Tripadvisor',
                                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                        // Dot indicator
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(
                                            maxDots,
                                            (dotIdx) {
                                              int activeDot = currentReviewIndex;
                                              if (reviews.length > 5) {
                                                if (currentReviewIndex > 2 && currentReviewIndex < reviews.length - 2) {
                                                  activeDot = 2; 
                                                } else if (currentReviewIndex >= reviews.length - 2) {
                                                  activeDot = maxDots - (reviews.length - currentReviewIndex);
                                                }
                                              }
                                              return AnimatedContainer(
                                                duration: const Duration(milliseconds: 300),
                                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                                width: dotIdx == activeDot ? 8 : 6,
                                                height: dotIdx == activeDot ? 8 : 6,
                                                decoration: BoxDecoration(
                                                  color: dotIdx == activeDot ? Colors.grey[700] : Colors.grey[300],
                                                  shape: BoxShape.circle,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    );
                                  },
                                )
                              else if (featuredReview != null) ...[
                                // Fallback to featured review if no reviews fetched
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('“', style: TextStyle(fontSize: 40, color: Color(0xFFDCDCDC), height: 1.1, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            featuredReview['comment'] ?? '',
                                            style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          _buildReviewStars((featuredReview['rating'] ?? 5).toDouble()),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${featuredReview['authorName'] ?? 'Người dùng'} — đánh giá Tripadvisor',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                              
                              // 'Giới thiệu' button
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.map_rounded, color: Color(0xFFE53935), size: 16),
                                      SizedBox(width: 6),
                                      Text('Giới thiệu', style: TextStyle(color: Color(0xFFE53935), fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Rating
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${place['rating'] ?? 5.0} (${place['userRatingCount'] ?? 0})',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                  ),
                                  const SizedBox(width: 8),
                                  Image.asset('assets/images/tripadvisor.jpg', width: 20, height: 20, fit: BoxFit.contain), // Tripadvisor logo
                                ],
                              ),
                              
                              if (place['openingHours'] != null) ...[
                                const SizedBox(height: 12),
                                ExpandableOpeningHours(hoursData: place['openingHours']),
                              ],

                              const SizedBox(height: 12),
                              
                              // Address
                              if (place['address']?.toString().isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on, color: Colors.grey, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          place['address'],
                                          style: const TextStyle(fontSize: 14, color: Colors.blue, height: 1.3),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: place['address']));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Đã sao chép địa chỉ'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        child: const Icon(
                                          Icons.copy,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              // Website
                              if (place['website']?.toString().isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.language, color: Colors.grey, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          place['website'],
                                          style: const TextStyle(fontSize: 14, color: Colors.blue, height: 1.3),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              // Phone
                              if (place['phone']?.toString().isNotEmpty == true)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.phone, color: Colors.grey, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          place['phone'],
                                          style: const TextStyle(fontSize: 14, color: Colors.blue, height: 1.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              const SizedBox(height: 8),
                            ] else ...[
                              // If not expanded, show only featured review if available
                              if (featuredReview != null) ...[
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('“', style: TextStyle(fontSize: 40, color: Color(0xFFDCDCDC), height: 1.1, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            featuredReview['comment'] ?? '',
                                            style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          _buildReviewStars((featuredReview['rating'] ?? 5).toDouble()),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${featuredReview['authorName'] ?? 'Người dùng'} — đánh giá Tripadvisor',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  'Xem chi tiết',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  } else if (itemType == 'SECTION_HEADER') {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        item['content'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  } else if (itemType == 'NOTE') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        item['content'] ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    );
                  }
                  
                  return const SizedBox();
                },
                childCount: items.length,
              ),
            ),
          ),
          
          // Extra bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 40),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExplorePostMapScreen(
                title: title,
                items: items,
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF1E1E2C),
        child: const Icon(Icons.map_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildTag(String text, {bool isRed = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isRed ? Colors.red.withOpacity(0.1) : Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isRed ? Colors.red : Colors.black87,
          fontSize: 12,
          fontWeight: isRed ? FontWeight.bold : FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _getSubCategoryText(dynamic subCategory) {
    if (subCategory is String) return subCategory;
    if (subCategory is Map) return subCategory['name']?.toString() ?? subCategory.values.first.toString();
    return subCategory.toString();
  }
}
