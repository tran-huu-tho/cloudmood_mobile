import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'explore_post_map_screen.dart';
import '../utils/time_utils.dart';
import '../utils/string_utils.dart';
import '../widgets/expandable_opening_hours.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/save_to_trip_bottom_sheet.dart';

class ExplorePostDetailScreen extends StatefulWidget {
  final int? postId;
  final String title;
  final Map<String, dynamic>? post;
  final Map<String, dynamic>? initialItinerary;

  const ExplorePostDetailScreen({
    Key? key,
    this.postId,
    required this.title,
    this.post,
    this.initialItinerary,
  }) : super(key: key);

  @override
  _ExplorePostDetailScreenState createState() => _ExplorePostDetailScreenState();
}

class _ExplorePostDetailScreenState extends State<ExplorePostDetailScreen> {
  Map<String, dynamic>? _post;
  bool _isLoading = true;
  final Set<int> _expandedPlaces = {};
  final Set<String> _collapsedSections = {};
  Map<int, int> _savedCounts = {};
  
  bool _isLiked = false;
  int _likeCount = 0;
  int _viewCount = 0;

  String _privacySetting = 'public';

  @override
  void initState() {
    super.initState();
    _loadPrivacySetting();
    if (widget.post != null) {
      _post = widget.post;
      _isLoading = false;
      _initStats();
      _fetchSavedCounts();
      if (widget.postId != null) {
        _fetchPostDetail(silent: true);
      }
    } else if (widget.postId != null) {
      _fetchPostDetail();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadPrivacySetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itineraryId = widget.initialItinerary?['id'] ?? _post?['itineraryId'] ?? _post?['id'];
      if (itineraryId != null) {
        final saved = prefs.getString('privacy_$itineraryId');
        if (saved != null && saved.isNotEmpty) {
          if (mounted) setState(() => _privacySetting = saved);
          return;
        }
      }
      final rawPrivacy = widget.post?['privacy'] ?? widget.initialItinerary?['privacy'];
      if (rawPrivacy != null && rawPrivacy.toString().isNotEmpty) {
        if (mounted) setState(() => _privacySetting = rawPrivacy.toString());
        return;
      }
      final isPublic = widget.initialItinerary?['isPublic'] ?? widget.post?['isPublic'];
      if (isPublic == false) {
        if (mounted) setState(() => _privacySetting = 'friends');
      } else {
        if (mounted) setState(() => _privacySetting = 'public');
      }
    } catch (_) {}
  }

  String get _privacyText {
    switch (_privacySetting) {
      case 'private':
        return 'Chỉ mình tôi';
      case 'friends':
        return 'Bạn bè';
      case 'public':
      default:
        return 'Công khai';
    }
  }

  IconData get _privacyIcon {
    switch (_privacySetting) {
      case 'private':
        return Icons.lock_rounded;
      case 'friends':
        return Icons.people_rounded;
      case 'public':
      default:
        return Icons.public_rounded;
    }
  }

  Color get _privacyColor {
    switch (_privacySetting) {
      case 'private':
        return Colors.red[600]!;
      case 'friends':
        return const Color(0xFF16A34A);
      case 'public':
      default:
        return const Color(0xFF0284C7);
    }
  }

  List get _availableSections {
    return widget.initialItinerary?['sections'] as List? ??
        _post?['originalItinerary']?['sections'] as List? ??
        _post?['itinerary']?['sections'] as List? ??
        _post?['sections'] as List? ??
        [];
  }

  String _resolveSectionName(List items, int itemIndex, dynamic item, dynamic place) {
    if (item['section'] != null && item['section'].toString().isNotEmpty) {
      return item['section'].toString();
    }
    if (place != null && place['section'] != null && place['section'].toString().isNotEmpty) {
      return place['section'].toString();
    }
    for (int i = itemIndex; i >= 0; i--) {
      if (i < items.length && items[i]['itemType'] == 'SECTION_HEADER' && items[i]['content'] != null) {
        return items[i]['content'].toString();
      }
    }
    return '';
  }

  Color _getSectionColor(List items, int itemIndex, dynamic item, dynamic place) {
    final secName = _resolveSectionName(items, itemIndex, item, place);
    final sections = _availableSections;
    for (var sec in sections) {
      if (sec is Map) {
        final name = (sec['name'] ?? '').toString();
        if ((secName.isNotEmpty && name.toLowerCase().trim() == secName.toLowerCase().trim()) || (secName.isEmpty && sections.length == 1)) {
          if (sec['colorCode'] != null) {
            try {
              final val = int.parse(sec['colorCode'].toString());
              return Color(val);
            } catch (_) {}
          }
        }
      }
    }
    final directColor = item['colorCode'] ?? place?['colorCode'];
    if (directColor != null) {
      try {
        return Color(int.parse(directColor.toString()));
      } catch (_) {}
    }
    return AppTheme.primary;
  }

  IconData? _getSectionIcon(List items, int itemIndex, dynamic item, dynamic place) {
    final secName = _resolveSectionName(items, itemIndex, item, place);
    final sections = _availableSections;
    for (var sec in sections) {
      if (sec is Map) {
        final name = (sec['name'] ?? '').toString();
        if ((secName.isNotEmpty && name.toLowerCase().trim() == secName.toLowerCase().trim()) || (secName.isEmpty && sections.length == 1)) {
          if (sec['iconCode'] != null) {
            try {
              final rawCode = int.parse(sec['iconCode'].toString());
              if (rawCode != 983363 && rawCode != 58055 && rawCode != 0) {
                return IconData(rawCode, fontFamily: 'MaterialIcons');
              }
            } catch (_) {}
          }
        }
      }
    }
    final directIcon = item['iconCode'] ?? place?['iconCode'];
    if (directIcon != null) {
      try {
        final rawCode = int.parse(directIcon.toString());
        if (rawCode != 983363 && rawCode != 58055 && rawCode != 0) {
          return IconData(rawCode, fontFamily: 'MaterialIcons');
        }
      } catch (_) {}
    }
    return null;
  }
  
  void _initStats() {
    if (_post == null) return;
    _likeCount = _post!['likeCount'] ?? 0;
    _viewCount = _post!['viewCount'] ?? 0;
    
    final myUserId = AuthService().currentUser.value?.id;
    final likesList = _post!['likes'] as List?;
    if (likesList != null && myUserId != null) {
      _isLiked = likesList.any((l) => l['userId'] == myUserId);
    }
  }

  Future<void> _fetchSavedCounts() async {
    final user = AuthService().currentUser.value;
    if (user != null && _post != null) {
      final newCounts = <int, int>{};
      final itemsRaw = _post!['items'] as List? ?? [];

      if (widget.initialItinerary != null) {
        // If initialItinerary is provided, count occurrences in its lists
        final trip = widget.initialItinerary!;
        final savedPlaces = trip['savedPlaces'] as List? ?? [];
        final detailsList = trip['details'] as List? ?? [];
        
        for (final item in itemsRaw) {
          if (item['itemType'] == 'PLACE') {
            final place = item['place'];
            if (place != null && place['id'] != null) {
              final targetId = place['id'];
              int listCount = 0;
              for (var d in savedPlaces) {
                if ((d['placeId'] ?? d['place']?['id']) == targetId &&
                    (d['section'] != null && d['section'].toString().isNotEmpty)) {
                  listCount++;
                }
              }
              for (var d in detailsList) {
                if ((d['placeId'] ?? d['place']?['id']) == targetId &&
                    d['day'] != null) {
                  listCount++;
                }
              }
              newCounts[targetId as int] = listCount;
            }
          }
        }
      } else {
        // Otherwise, fetch all trips and count trips
        final trips = await DatabaseService().fetchUserItineraries(
          int.parse(user.id.toString()),
          isGuide: false,
        );
        for (final item in itemsRaw) {
          if (item['itemType'] == 'PLACE') {
            final place = item['place'];
            if (place != null && place['id'] != null) {
              final targetId = place['id'];
              int tripsCount = 0;
              for (var trip in trips) {
                bool foundInTrip = false;
                final savedPlaces = trip['savedPlaces'] as List? ?? [];
                final detailsList = trip['details'] as List? ?? [];

                for (var d in savedPlaces) {
                  if ((d['placeId'] ?? d['place']?['id']) == targetId &&
                      (d['section'] != null && d['section'].toString().isNotEmpty)) {
                    foundInTrip = true;
                    break;
                  }
                }
                if (!foundInTrip) {
                  for (var d in detailsList) {
                    if ((d['placeId'] ?? d['place']?['id']) == targetId &&
                        d['day'] != null) {
                      foundInTrip = true;
                      break;
                    }
                  }
                }
                if (foundInTrip) {
                  tripsCount++;
                }
              }
              newCounts[targetId as int] = tripsCount;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _savedCounts = newCounts;
        });
      }
    }
  }

  Future<void> _fetchPostDetail({bool silent = false}) async {
    try {
      if (!silent) {
        if (mounted) setState(() => _isLoading = true);
      }
      final response = await ApiClient.get('/explore/${widget.postId}');
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _post = jsonDecode(response.body);
          _initStats();
          _isLoading = false;
        });
        _fetchSavedCounts();
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching post details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (widget.postId == null) return;
    
    final newIsLiked = !_isLiked;
    setState(() {
      _isLiked = newIsLiked;
      _likeCount += newIsLiked ? 1 : -1;
    });
    
    try {
      if (newIsLiked) {
        await ApiClient.post('/explore/${widget.postId}/like');
      } else {
        await ApiClient.delete('/explore/${widget.postId}/like');
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = !newIsLiked;
        _likeCount += !newIsLiked ? 1 : -1;
      });
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

    final coverImage = (_post!['coverImage'] != null && _post!['coverImage'].toString().isNotEmpty && !_post!['coverImage'].toString().contains('via.placeholder.com')) 
        ? _post!['coverImage'] 
        : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1200&q=80';
    final title = _post!['title'] ?? '';
    final description = _post!['description'] ?? '';
    
    final isPlatform = _post!['postType'] == 'PLATFORM_CURATION';
    final platformName = _post!['platformName'] ?? '';
    final platformLogo = _post!['platformLogo'] ?? '';
    
    final authorName = isPlatform 
        ? platformName 
        : (_post!['author']?['fullName'] ?? 'Người dùng Ẩn danh');
    
    final authorAvatar = _post!['author']?['avatar']?.toString() ?? '';
    final avatarUrl = isPlatform 
        ? platformLogo 
        : (authorAvatar.isNotEmpty && !authorAvatar.contains('via.placeholder.com')
            ? authorAvatar 
            : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&q=80');

    final itemsRaw = _post!['items'] as List? ?? [];
    
    // Filter items based on collapsed sections
    final List<dynamic> items = [];
    String? currentSection;
    for (final item in itemsRaw) {
      if (item['itemType'] == 'SECTION_HEADER') {
        currentSection = item['content'];
        items.add(item);
      } else {
        if (currentSection == null || !_collapsedSections.contains(currentSection)) {
          items.add(item);
        }
      }
    }

    int placeCounter = 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Hero Header with Cover Image and Overlaid Title
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(90),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(90),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_circle_down_rounded, color: Colors.white, size: 20),
                    onPressed: () {},
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 56),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4.0,
                      color: Colors.black87,
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    coverImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]),
                  ),
                  // Dark Gradient Overlay for readability
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(60),
                          Colors.transparent,
                          Colors.black.withAlpha(220),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 2. Author / Platform Info Row
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: AppTheme.border.withAlpha(120)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary.withAlpha(100), width: 1.5),
                    ),
                    child: ClipOval(
                      child: isPlatform
                          ? Container(
                              color: AppTheme.primaryContainer,
                              child: const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 20),
                            )
                          : Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.person, color: Colors.grey),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPlatform 
                              ? (authorName.toLowerCase().startsWith('từ ') ? authorName : 'Từ $authorName') 
                              : authorName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPlatform ? 'Nguồn tổng hợp từ đối tác' : 'Tác giả bài viết',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtitleText,
                          ),
                        ),
                        if (!isPlatform) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(_privacyIcon, size: 12, color: _privacyColor),
                              const SizedBox(width: 4),
                              Text(
                                _privacyText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _privacyColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isPlatform)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer.withAlpha(120),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Mở bài viết',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        InkWell(
                          onTap: _toggleLike,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isLiked ? Colors.red.withAlpha(20) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: _isLiked ? Colors.red : Colors.grey[600],
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$_likeCount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _isLiked ? Colors.red : Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.remove_red_eye_rounded, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '$_viewCount',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          // 3. Description Section
          if (description.isNotEmpty && !isPlatform)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border.withAlpha(100)),
                ),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkText,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          
          // 4. List of Items (Places / Headers / Notes)
          SliverList(
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
                  String content = item['content'] ?? '';
                  if (content.isEmpty) {
                    content = place['description'] ?? '';
                  }
                  
                  final currentIndex = placeCounter++;
                  int currentReviewIndex = 0;

                  final isExpanded = _expandedPlaces.contains(currentIndex);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14, left: 16, right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border.withAlpha(120)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(6),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedPlaces.remove(currentIndex);
                          } else {
                            _expandedPlaces.add(currentIndex);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                                child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Index badge, Place Name, Save Button
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final secColor = _getSectionColor(items, index, item, place);
                                    final secIcon = _getSectionIcon(items, index, item, place);
                                    return Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: secColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: secColor.withAlpha(80),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: (secIcon == null)
                                            ? Text(
                                                '$currentIndex',
                                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                              )
                                            : Icon(
                                                secIcon,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      placeName,
                                      style: TextStyle(
                                        fontSize: 16, 
                                        fontWeight: FontWeight.w700, 
                                        color: AppTheme.darkText,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Builder(
                                  builder: (context) {
                                    final placeId = place['id'] as int?;
                                    final savedCount = (placeId != null) ? (_savedCounts[placeId] ?? 0) : 0;
                                    final isSaved = savedCount > 0;
                                    
                                    final isInsideTrip = widget.initialItinerary != null;
                                    final savedText = isSaved
                                        ? (savedCount > 1 ? 'Đã thêm ($savedCount)' : 'Đã thêm')
                                        : (isInsideTrip ? 'Thêm vào' : 'Lưu');
                                    
                                    return GestureDetector(
                                      onTap: () {
                                        if (placeId != null) {
                                          SaveToTripBottomSheet.show(
                                            context,
                                            place,
                                            initialItinerary: widget.initialItinerary,
                                            onSaved: () {
                                              _fetchSavedCounts();
                                            },
                                          );
                                        }
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: isSaved ? Colors.grey[200] : const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isSaved ? Icons.bookmark : Icons.bookmark_border, 
                                              color: isSaved ? Colors.black : Colors.white, 
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isSaved ? savedText : 'Thêm', 
                                              style: TextStyle(
                                                color: isSaved ? Colors.black : Colors.white, 
                                                fontSize: 12, 
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (isSaved) ...[
                                              const SizedBox(width: 2),
                                              const Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 14),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Category Tags & Status
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
                              },
                            ),
                            const SizedBox(height: 14),
                            
                            // Content text & Image Thumbnail
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    content.isNotEmpty ? content : (place['description']?.toString().isNotEmpty == true ? place['description'] : 'Đang cập nhật thông tin...'),
                                    style: TextStyle(
                                      fontSize: 14, 
                                      color: AppTheme.darkText.withAlpha(220), 
                                      height: 1.45,
                                    ),
                                    maxLines: isExpanded ? null : 3,
                                    overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    placeImage,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 80, 
                                      height: 80, 
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            // Expanded Section (Reviews & Details)
                            if (isExpanded) ...[
                              const SizedBox(height: 16),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 14),
                              
                              if ((place['reviews'] as List?)?.isNotEmpty == true) ...[
                                StatefulBuilder(
                                  builder: (context, setLocalState) {
                                    final reviews = place['reviews'] as List;

                                    return Column(
                                      children: [
                                        SizedBox(
                                          height: 140,
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
                                              return Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: AppTheme.border.withAlpha(80)),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('“', style: TextStyle(fontSize: 32, color: AppTheme.primary, height: 1.0, fontWeight: FontWeight.bold)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            review['comment'] ?? '',
                                                            style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.35),
                                                            maxLines: 3,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const Spacer(),
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              _buildReviewStars((review['rating'] ?? 5).toDouble()),
                                                              const SizedBox(width: 4),
                                                              Flexible(
                                                                child: Text(
                                                                  '${review['authorName'] ?? 'Người dùng'} (Tripadvisor)',
                                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ] else if (featuredReview != null) ...[
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
                              
                              // Interactive Map button to open map and zoom location
                              Align(
                                alignment: Alignment.centerLeft,
                                child: GestureDetector(
                                  onTap: () {
                                    final placeId = place['id'] as int?;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ExplorePostMapScreen(
                                          title: widget.title,
                                          items: items,
                                          sections: _availableSections,
                                          initialPlaceId: placeId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.map_rounded, color: Color(0xFF1D4ED8), size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'Bản đồ',
                                          style: TextStyle(
                                            color: Color(0xFF1D4ED8),
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                          StringUtils.cleanAddress(place['address'] ?? ''),
                                          style: const TextStyle(fontSize: 14, color: Colors.blue, height: 1.3),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: StringUtils.cleanAddress(place['address'] ?? '')));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Đã sao chép địa chỉ'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        child: const Icon(Icons.copy, size: 16, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),

                              // Website
                              Builder(
                                builder: (context) {
                                  final website = (place['website'] ?? place['webUrl'] ?? '').toString();
                                  if (website.isEmpty) return const SizedBox();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.language, color: Colors.grey, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () async {
                                              final Uri url = Uri.parse(website.startsWith('http') ? website : 'https://$website');
                                              if (await canLaunchUrl(url)) {
                                                await launchUrl(url, mode: LaunchMode.externalApplication);
                                              }
                                            },
                                            child: Text(
                                              website,
                                              style: const TextStyle(fontSize: 14, color: Colors.blue, height: 1.3, decoration: TextDecoration.underline),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              
                              // Phone
                              Builder(
                                builder: (context) {
                                  final phone = (place['phone'] ?? place['phoneNumber'] ?? place['contactPhone'] ?? '').toString();
                                  if (phone.isEmpty) return const SizedBox();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.phone, color: Colors.grey, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () async {
                                              final Uri phoneUri = Uri(scheme: 'tel', path: phone);
                                              if (await canLaunchUrl(phoneUri)) {
                                                await launchUrl(phoneUri);
                                              }
                                            },
                                            child: Text(
                                              phone,
                                              style: const TextStyle(fontSize: 14, color: Colors.blue, height: 1.3),
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: phone));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Đã sao chép số điện thoại'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          child: const Icon(Icons.copy, size: 16, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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
                    ),
                  );
                  } else if (itemType == 'SECTION_HEADER') {
                    final bool isFirstSection = index == 0 || items.take(index).where((it) => it['itemType'] == 'SECTION_HEADER').isEmpty;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isFirstSection)
                          Container(
                            height: 12,
                            width: double.infinity,
                            color: const Color(0xFFF3F4F6),
                          ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              final sectionName = item['content'] ?? '';
                              if (_collapsedSections.contains(sectionName)) {
                                _collapsedSections.remove(sectionName);
                              } else {
                                _collapsedSections.add(sectionName);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                            child: Row(
                              children: [
                                Icon(
                                  _collapsedSections.contains(item['content']) ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
                                  size: 24,
                                  color: Colors.black87,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item['content'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  } else if (itemType == 'NOTE') {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF9CA3AF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.insert_drive_file, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  item['content'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (itemType == 'TODO') {
                    String title = item['content'] ?? 'Danh sách công việc';
                    List<dynamic> todoList = [];
                    
                    try {
                      final parsedContent = jsonDecode(title);
                      if (parsedContent is Map) {
                        title = parsedContent['title'] ?? 'Danh sách công việc';
                        todoList = parsedContent['items'] ?? [];
                      }
                    } catch (_) {}

                    final rawTodo = item['todoItems'];
                    if (rawTodo != null && todoList.isEmpty) {
                      if (rawTodo is List) {
                        todoList = rawTodo;
                      } else if (rawTodo is String) {
                        try {
                          todoList = json.decode(rawTodo) as List;
                        } catch (_) {}
                      }
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE2E8F0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.fact_check_outlined,
                                    color: AppTheme.subtitleText,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            if (todoList.isNotEmpty) const SizedBox(height: 12),
                            ...todoList.map((todo) {
                              final isDone = todo['done'] == true;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: isDone ? Colors.green : Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        todo['text'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDone ? Colors.grey : Colors.black87,
                                          decoration: isDone ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  return const SizedBox();
                },
                childCount: items.length,
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
