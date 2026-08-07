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
  _ExplorePostDetailScreenState createState() =>
      _ExplorePostDetailScreenState();
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
      final itineraryId =
          widget.initialItinerary?['id'] ??
          _post?['itineraryId'] ??
          _post?['id'];
      if (itineraryId != null) {
        final saved = prefs.getString('privacy_$itineraryId');
        if (saved != null && saved.isNotEmpty) {
          if (mounted) setState(() => _privacySetting = saved);
          return;
        }
      }
      final rawPrivacy =
          widget.post?['privacy'] ?? widget.initialItinerary?['privacy'];
      if (rawPrivacy != null && rawPrivacy.toString().isNotEmpty) {
        if (mounted) setState(() => _privacySetting = rawPrivacy.toString());
        return;
      }
      final isPublic =
          widget.initialItinerary?['isPublic'] ?? widget.post?['isPublic'];
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

  String _resolveSectionName(
    List items,
    int itemIndex,
    dynamic item,
    dynamic place,
  ) {
    if (item['section'] != null && item['section'].toString().isNotEmpty) {
      return item['section'].toString();
    }
    if (place != null &&
        place['section'] != null &&
        place['section'].toString().isNotEmpty) {
      return place['section'].toString();
    }
    for (int i = itemIndex; i >= 0; i--) {
      if (i < items.length &&
          items[i]['itemType'] == 'SECTION_HEADER' &&
          items[i]['content'] != null) {
        return items[i]['content'].toString();
      }
    }
    return '';
  }

  Color _getSectionColor(
    List items,
    int itemIndex,
    dynamic item,
    dynamic place,
  ) {
    final secName = _resolveSectionName(items, itemIndex, item, place);
    final sections = _availableSections;
    for (var sec in sections) {
      if (sec is Map) {
        final name = (sec['name'] ?? '').toString();
        if ((secName.isNotEmpty &&
                name.toLowerCase().trim() == secName.toLowerCase().trim()) ||
            (secName.isEmpty && sections.length == 1)) {
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

  IconData? _getSectionIcon(
    List items,
    int itemIndex,
    dynamic item,
    dynamic place,
  ) {
    final secName = _resolveSectionName(items, itemIndex, item, place);
    final sections = _availableSections;
    for (var sec in sections) {
      if (sec is Map) {
        final name = (sec['name'] ?? '').toString();
        if ((secName.isNotEmpty &&
                name.toLowerCase().trim() == secName.toLowerCase().trim()) ||
            (secName.isEmpty && sections.length == 1)) {
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
                    (d['section'] != null &&
                        d['section'].toString().isNotEmpty)) {
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
                      (d['section'] != null &&
                          d['section'].toString().isNotEmpty)) {
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

  String _getAuthorNoteForPlace(dynamic item, dynamic place) {
    if (item == null && place == null) return '';
    final iMap = item is Map ? item : {};
    final pMap = place is Map ? place : {};

    final String placeDesc = (pMap['description'] ?? '').toString().trim();

    // 1. Direct item content/note fields
    final String itemContent = (iMap['content'] ?? iMap['note'] ?? iMap['noteText'] ?? '').toString().trim();
    if (itemContent.isNotEmpty && itemContent != placeDesc) {
      return itemContent;
    }

    final placeNote = (pMap['noteText'] ?? pMap['note'] ?? '').toString().trim();
    if (placeNote.isNotEmpty && placeNote != placeDesc) {
      return placeNote;
    }

    final placeId = pMap['id'] ?? iMap['placeId'];

    // 2. Check widget.initialItinerary savedPlaces and details
    if (widget.initialItinerary != null) {
      final saved = widget.initialItinerary!['savedPlaces'] as List?;
      if (saved != null) {
        for (var sp in saved) {
          if (sp is Map) {
            final spId = sp['placeId'] ?? sp['place']?['id'];
            if (placeId != null && spId?.toString() == placeId.toString()) {
              final note = (sp['noteText'] ?? sp['note'] ?? sp['notes'] ?? '').toString().trim();
              if (note.isNotEmpty) return note;
            }
          }
        }
      }
      final details = widget.initialItinerary!['details'] as List?;
      if (details != null) {
        for (var d in details) {
          if (d is Map) {
            final dId = d['placeId'] ?? d['place']?['id'];
            if (placeId != null && dId?.toString() == placeId.toString()) {
              final note = (d['noteText'] ?? d['note'] ?? d['notes'] ?? '').toString().trim();
              if (note.isNotEmpty) return note;
            }
          }
        }
      }
    }

    // 3. Check _post['originalItinerary'] savedPlaces and details
    if (_post != null && _post!['originalItinerary'] != null) {
      final orig = _post!['originalItinerary'];
      if (orig is Map) {
        final saved = orig['savedPlaces'] as List?;
        if (saved != null) {
          for (var sp in saved) {
            if (sp is Map) {
              final spId = sp['placeId'] ?? sp['place']?['id'];
              if (placeId != null && spId?.toString() == placeId.toString()) {
                final note = (sp['noteText'] ?? sp['note'] ?? sp['notes'] ?? '').toString().trim();
                if (note.isNotEmpty) return note;
              }
            }
          }
        }
        final details = orig['details'] as List?;
        if (details != null) {
          for (var d in details) {
            if (d is Map) {
              final dId = d['placeId'] ?? d['place']?['id'];
              if (placeId != null && dId?.toString() == placeId.toString()) {
                final note = (d['noteText'] ?? d['note'] ?? d['notes'] ?? '').toString().trim();
                if (note.isNotEmpty) return note;
              }
            }
          }
        }
      }
    }

    return '';
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

  Widget _buildSkeletonLoading(BuildContext context) {
    final titleText = widget.title.isNotEmpty ? widget.title : 'Đang tải bài viết...';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Cover Image Skeleton
                Container(
                  height: 250,
                  width: double.infinity,
                  color: const Color(0xFFE2E8F0),
                ),
                const SizedBox(height: 16),
                // 2. Title Skeleton / Title Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                // 3. Author Card Skeleton
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border.withAlpha(100)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 14,
                              width: 140,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 11,
                              width: 90,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 4. Place Cards Skeleton
                for (int i = 0; i < 2; i++)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border.withAlpha(100)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              height: 16,
                              width: 160,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 14,
                          width: 220,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Floating Glass Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(235),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF0F172A),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSkeletonLoading(context);
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lỗi')),
        body: const Center(child: Text('Không tìm thấy bài viết')),
      );
    }

    final coverImage =
        (_post!['coverImage'] != null &&
            _post!['coverImage'].toString().isNotEmpty &&
            !_post!['coverImage'].toString().contains('via.placeholder.com'))
        ? _post!['coverImage']
        : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1200&q=80';
    final title = _post!['title'] ?? '';
    String rawDescription = (_post!['description'] ?? '').toString().trim();
    if (rawDescription.isEmpty && widget.initialItinerary != null) {
      rawDescription = (widget.initialItinerary!['description'] ?? '').toString().trim();
    }
    if (rawDescription.isEmpty && _post!['originalItinerary'] != null) {
      rawDescription = (_post!['originalItinerary']?['description'] ?? '').toString().trim();
    }
    final description = (rawDescription.isNotEmpty &&
            rawDescription.toLowerCase() != 'public' &&
            rawDescription.toLowerCase() != 'private' &&
            rawDescription.toLowerCase() != 'friends' &&
            rawDescription.toLowerCase() != 'null' &&
            rawDescription.toLowerCase() != 'undefined')
        ? rawDescription
        : '';

    final rawPlatformName = (_post!['platformName'] ?? '').toString().trim();
    final rawPlatformLogo = (_post!['platformLogo'] ?? '').toString().trim();
    final hasPlatform = rawPlatformName.isNotEmpty || rawPlatformLogo.isNotEmpty;
    final isPlatform = hasPlatform;

    final authorName = hasPlatform
        ? (rawPlatformName.isNotEmpty ? rawPlatformName : 'Đối tác du lịch')
        : (_post!['author']?['fullName'] ?? 'Cloud Mood');

    final authorAvatar = _post!['author']?['avatar']?.toString() ?? '';
    String avatarUrl = '';
    if (hasPlatform) {
      if (rawPlatformLogo.isNotEmpty) {
        avatarUrl = rawPlatformLogo.startsWith('/') ? '${ApiClient.baseUrl}$rawPlatformLogo' : rawPlatformLogo;
      }
    } else if (authorAvatar.isNotEmpty && !authorAvatar.contains('via.placeholder.com')) {
      avatarUrl = authorAvatar.startsWith('/') ? '${ApiClient.baseUrl}$authorAvatar' : authorAvatar;
    }

    final itemsRaw = _post!['items'] as List? ?? [];

    // Filter items based on collapsed sections
    final List<dynamic> items = [];
    String? currentSection;
    for (final item in itemsRaw) {
      if (item['itemType'] == 'SECTION_HEADER') {
        currentSection = item['content'];
        items.add(item);
      } else {
        if (currentSection == null ||
            !_collapsedSections.contains(currentSection)) {
          items.add(item);
        }
      }
    }

    int placeCounter = 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Hero Header Cover Image
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: Image.network(
                    coverImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey[800]),
                  ),
                ),
              ),

          // 2. Post Title (Black Text)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  height: 1.3,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),

          // 3. Author / Platform Info Card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Avatar + Name/Source + Optional "Mở bài viết" button
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primary.withAlpha(100),
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: avatarUrl.isNotEmpty
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFEEF2FF),
                                    child: const Icon(
                                      Icons.travel_explore_rounded,
                                      color: Color(0xFF4F46E5),
                                      size: 22,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFFEEF2FF),
                                  child: const Icon(
                                    Icons.travel_explore_rounded,
                                    color: Color(0xFF4F46E5),
                                    size: 22,
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
                              hasPlatform
                                  ? (authorName.toLowerCase().startsWith('từ ') || authorName.toLowerCase().startsWith('theo ')
                                        ? authorName
                                        : 'Từ $authorName')
                                  : authorName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasPlatform
                                  ? 'Nguồn đối tác du lịch uy tín'
                                  : 'Tác giả bài viết',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.subtitleText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isPlatform)
                        GestureDetector(
                          onTap: () async {
                            final rawUrl = (_post!['originalUrl'] ?? _post!['sourceUrl'] ?? _post!['url'] ?? '').toString();
                            if (rawUrl.isNotEmpty) {
                              final uri = Uri.tryParse(rawUrl);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryContainer.withAlpha(140),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 13,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Mở bài viết',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  // Bottom Row: Stats (Heart / Like, Views, Privacy Badge)
                  Row(
                    children: [
                      // Like button (Thả tim)
                      InkWell(
                        onTap: _toggleLike,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isLiked
                                ? Colors.red.withAlpha(20)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: _isLiked
                                    ? Colors.red
                                    : Colors.grey[600],
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$_likeCount',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _isLiked
                                      ? Colors.red
                                      : Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // View count (Lượt xem)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.remove_red_eye_rounded,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$_viewCount',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isPlatform) ...[
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              _privacyIcon,
                              size: 13,
                              color: _privacyColor,
                            ),
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
                ],
              ),
            ),
          ),

          // 3. Guide Introduction / Description Section
          if (description.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF8FAFC),
                      Color(0xFFEFF6FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFDBEAFE),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withAlpha(12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Color(0xFF2563EB),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Lời giới thiệu cẩm nang',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.only(left: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Color(0xFF3B82F6),
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF334155),
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. List of Items (Places / Headers / Notes)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              final itemType = item['itemType'];

              if (itemType == 'PLACE') {
                final place = item['place'];
                if (place == null) return const SizedBox();

                final placeName = place['name'] ?? '';
                final placeImage =
                    place['image'] ?? 'https://via.placeholder.com/300x200';
                final category = place['category']?['name'] ?? 'Địa điểm';
                final featuredReview =
                    item['featuredReview'] ??
                    place['featuredReview'] ??
                    (place['reviews'] is List &&
                            (place['reviews'] as List).isNotEmpty
                        ? (place['reviews'] as List).first
                        : null);
                final String authorNote = _getAuthorNoteForPlace(item, place);
                String content = item['content'] ?? '';
                if (authorNote.isNotEmpty && authorNote != place['description']) {
                  content = authorNote;
                } else if (content.isEmpty) {
                  content = place['description'] ?? '';
                }

                final currentIndex = placeCounter++;
                int currentReviewIndex = 0;

                final isExpanded = _expandedPlaces.contains(currentIndex);

                return Container(
                  margin: const EdgeInsets.only(
                    bottom: 14,
                    left: 16,
                    right: 16,
                  ),
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
                                  final secColor = _getSectionColor(
                                    items,
                                    index,
                                    item,
                                    place,
                                  );
                                  final secIcon = _getSectionIcon(
                                    items,
                                    index,
                                    item,
                                    place,
                                  );
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
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
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
                                  final savedCount = (placeId != null)
                                      ? (_savedCounts[placeId] ?? 0)
                                      : 0;
                                  final isSaved = savedCount > 0;

                                  final isInsideTrip =
                                      widget.initialItinerary != null;
                                  final savedText = isSaved
                                      ? (savedCount > 1
                                            ? 'Đã thêm ($savedCount)'
                                            : 'Đã thêm')
                                      : (isInsideTrip ? 'Thêm vào' : 'Lưu');

                                  return GestureDetector(
                                    onTap: () {
                                      if (placeId != null) {
                                        SaveToTripBottomSheet.show(
                                          context,
                                          place,
                                          initialItinerary:
                                              widget.initialItinerary,
                                          onSaved: () {
                                            _fetchSavedCounts();
                                          },
                                        );
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSaved
                                            ? Colors.grey[200]
                                            : const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSaved
                                                ? Icons.bookmark
                                                : Icons.bookmark_border,
                                            color: isSaved
                                                ? Colors.black
                                                : Colors.white,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isSaved ? savedText : 'Thêm',
                                            style: TextStyle(
                                              color: isSaved
                                                  ? Colors.black
                                                  : Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (isSaved) ...[
                                            const SizedBox(width: 2),
                                            const Icon(
                                              Icons.keyboard_arrow_down,
                                              color: Colors.black,
                                              size: 14,
                                            ),
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
                              final hoursText = TimeUtils.getOpeningHoursText(
                                place['openingHours'],
                              );
                              final isClosed = hoursText.toLowerCase().contains(
                                'đóng cửa',
                              );

                              return Row(
                                children: [
                                  if (isClosed) ...[
                                    Flexible(
                                      child: _buildTag(
                                        'Tạm đóng cửa',
                                        isRed: true,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(child: _buildTag(category)),
                                  if ((place['subCategories'] as List?)
                                          ?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: _buildTag(
                                        _getSubCategoryText(
                                          (place['subCategories'] as List)
                                              .first,
                                        ),
                                      ),
                                    ),
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
                                  content.isNotEmpty
                                      ? content
                                      : (place['description']
                                                    ?.toString()
                                                    .isNotEmpty ==
                                                true
                                            ? place['description']
                                            : 'Đang cập nhật thông tin...'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.darkText.withAlpha(220),
                                    height: 1.45,
                                  ),
                                  maxLines: isExpanded ? null : 3,
                                  overflow: isExpanded
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
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
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                    ),
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

                            if ((place['reviews'] as List?)?.isNotEmpty ==
                                true) ...[
                              StatefulBuilder(
                                builder: (context, setLocalState) {
                                  final reviews = place['reviews'] as List;

                                  if (reviews.length == 1) {
                                    final review = reviews[0];
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppTheme.border.withAlpha(80),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '“',
                                            style: TextStyle(
                                              fontSize: 32,
                                              color: AppTheme.primary,
                                              height: 1.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  review['comment'] ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black87,
                                                    height: 1.35,
                                                  ),
                                                  maxLines: 4,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    _buildReviewStars(
                                                      (review['rating'] ?? 5).toDouble(),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        '${review['authorName'] ?? 'Người dùng'} (Tripadvisor)',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: AppTheme.primary,
                                                        ),
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
                                  }

                                  return Column(
                                    children: [
                                      SizedBox(
                                        height: 110,
                                        child: PageView.builder(
                                          controller: PageController(
                                            viewportFraction: 1.0,
                                          ),
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
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: AppTheme.border
                                                      .withAlpha(80),
                                                ),
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    '“',
                                                    style: TextStyle(
                                                      fontSize: 32,
                                                      color: AppTheme.primary,
                                                      height: 1.0,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          review['comment'] ??
                                                              '',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                color: Colors
                                                                    .black87,
                                                                height: 1.35,
                                                              ),
                                                          maxLines: 3,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            _buildReviewStars(
                                                              (review['rating'] ??
                                                                      5)
                                                                  .toDouble(),
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Flexible(
                                                              child: Text(
                                                                '${review['authorName'] ?? 'Người dùng'} (Tripadvisor)',
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: AppTheme
                                                                      .primary,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
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
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.border.withAlpha(80),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '“',
                                      style: TextStyle(
                                        fontSize: 32,
                                        color: AppTheme.primary,
                                        height: 1.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            featuredReview['comment'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                              height: 1.35,
                                            ),
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildReviewStars(
                                                (featuredReview['rating'] ?? 5)
                                                    .toDouble(),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '${featuredReview['authorName'] ?? 'Người dùng'} (Tripadvisor)',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.primary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // Interactive Map button to open map and zoom location
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () {
                                  final placeId = place['id'] as int?;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ExplorePostMapScreen(
                                            title: widget.title,
                                            items: items,
                                            sections: _availableSections,
                                            initialPlaceId: placeId,
                                          ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFBFDBFE),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.map_rounded,
                                        color: Color(0xFF1D4ED8),
                                        size: 16,
                                      ),
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
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(place['rating'] as num?)?.toDouble() ?? 0.0} (${place['userRatingCount'] ?? 0})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Image.asset(
                                  'assets/images/tripadvisor.jpg',
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ), // Tripadvisor logo
                              ],
                            ),

                            if (place['openingHours'] != null) ...[
                              const SizedBox(height: 12),
                              ExpandableOpeningHours(
                                hoursData: place['openingHours'],
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Address
                            if (place['address']?.toString().isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        StringUtils.cleanAddress(
                                          place['address'] ?? '',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: StringUtils.cleanAddress(
                                              place['address'] ?? '',
                                            ),
                                          ),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Đã sao chép địa chỉ',
                                            ),
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
                            Builder(
                              builder: (context) {
                                String cleanVal(dynamic val) {
                                  if (val == null) return '';
                                  final str = val.toString().trim();
                                  if (str.toLowerCase() == 'null' ||
                                      str.toLowerCase() == 'undefined' ||
                                      str.toLowerCase() == 'n/a' ||
                                      str.toLowerCase() == 'none')
                                    return '';
                                  return str;
                                }

                                String website = cleanVal(place['website']);
                                if (website.isEmpty)
                                  website = cleanVal(place['websiteUri']);
                                if (website.isEmpty)
                                  website = cleanVal(place['webUrl']);
                                if (website.isEmpty)
                                  website = cleanVal(place['websiteUrl']);
                                if (website.isEmpty)
                                  website = cleanVal(place['customWebsite']);
                                if (website.isEmpty)
                                  website = cleanVal(place['link']);
                                if (website.isEmpty)
                                  website = cleanVal(place['url']);
                                if (website.isEmpty)
                                  website = cleanVal(item['website']);
                                if (website.isEmpty)
                                  website = cleanVal(item['link']);
                                if (website.isEmpty)
                                  website = cleanVal(item['url']);
                                if (website.isEmpty)
                                  return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.language,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () async {
                                            final Uri url = Uri.parse(
                                              website.startsWith('http')
                                                  ? website
                                                  : 'https://$website',
                                            );
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(
                                                url,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            }
                                          },
                                          child: Text(
                                            website,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.blue,
                                              height: 1.3,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
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
                                String cleanVal(dynamic val) {
                                  if (val == null) return '';
                                  final str = val.toString().trim();
                                  if (str.toLowerCase() == 'null' ||
                                      str.toLowerCase() == 'undefined' ||
                                      str.toLowerCase() == 'n/a' ||
                                      str.toLowerCase() == 'none')
                                    return '';
                                  return str;
                                }

                                String phone = cleanVal(place['phone']);
                                if (phone.isEmpty)
                                  phone = cleanVal(place['phoneNumber']);
                                if (phone.isEmpty)
                                  phone = cleanVal(
                                    place['internationalPhoneNumber'],
                                  );
                                if (phone.isEmpty)
                                  phone = cleanVal(
                                    place['formattedPhoneNumber'],
                                  );
                                if (phone.isEmpty)
                                  phone = cleanVal(place['contactPhone']);
                                if (phone.isEmpty)
                                  phone = cleanVal(place['customPhone']);
                                if (phone.isEmpty)
                                  phone = cleanVal(item['phone']);
                                if (phone.isEmpty)
                                  phone = cleanVal(item['phoneNumber']);
                                if (phone.isEmpty)
                                  phone = cleanVal(item['contactPhone']);
                                if (phone.isEmpty)
                                  return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.phone,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () async {
                                            final cleanPhone = phone.replaceAll(
                                              RegExp(r'[^\d+]'),
                                              '',
                                            );
                                            final Uri phoneUri = Uri(
                                              scheme: 'tel',
                                              path: cleanPhone,
                                            );
                                            if (await canLaunchUrl(phoneUri)) {
                                              await launchUrl(phoneUri);
                                            }
                                          },
                                          child: Text(
                                            phone,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.blue,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(
                                            ClipboardData(text: phone),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Đã sao chép số điện thoại',
                                              ),
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
                                );
                              },
                            ),

                            const SizedBox(height: 8),
                          ] else ...[
                            // If not expanded, show only featured review if available
                            if (_extractReviewText(
                              featuredReview,
                            ).isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.border.withAlpha(80),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '“',
                                      style: TextStyle(
                                        fontSize: 32,
                                        color: AppTheme.primary,
                                        height: 1.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _extractReviewText(featuredReview),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                              height: 1.35,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildReviewStars(
                                                _extractReviewRating(
                                                  featuredReview,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  '${_extractReviewAuthor(featuredReview)} — đánh giá Tripadvisor',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.primary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                'Xem chi tiết',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              } else if (itemType == 'SECTION_HEADER') {
                final bool isFirstSection =
                    index == 0 ||
                    items
                        .take(index)
                        .where((it) => it['itemType'] == 'SECTION_HEADER')
                        .isEmpty;
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
                              _collapsedSections.contains(item['content'])
                                  ? Icons.keyboard_arrow_right
                                  : Icons.keyboard_arrow_down,
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
                  padding: const EdgeInsets.only(
                    bottom: 16,
                    left: 16,
                    right: 16,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                          child: const Icon(
                            Icons.insert_drive_file,
                            color: Colors.white,
                            size: 16,
                          ),
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
                  padding: const EdgeInsets.only(
                    bottom: 16,
                    left: 16,
                    right: 16,
                  ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
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
                                  isDone
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isDone ? Colors.green : Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    todo['text'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDone
                                          ? Colors.grey
                                          : Colors.black87,
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
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
            }, childCount: items.length),
          ),

          // Extra bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
      Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(235),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(10.0),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A),
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
  floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ExplorePostMapScreen(title: title, items: items),
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
    if (subCategory is Map)
      return subCategory['name']?.toString() ??
          subCategory.values.first.toString();
    return subCategory.toString();
  }

  String _extractReviewText(dynamic review) {
    if (review == null) return '';
    if (review is String) return review.trim();
    if (review is Map) {
      final text =
          review['comment'] ??
          review['text'] ??
          review['content'] ??
          review['review'] ??
          review['body'] ??
          review['commentText'] ??
          review['description'];
      if (text != null && text.toString().trim().isNotEmpty) {
        return text.toString().trim();
      }
    }
    return '';
  }

  String _extractReviewAuthor(dynamic review) {
    if (review is Map) {
      final author =
          review['authorName'] ??
          review['author_name'] ??
          review['userName'] ??
          review['user_name'] ??
          review['author'] ??
          review['user'];
      if (author != null && author.toString().trim().isNotEmpty) {
        return author.toString().trim();
      }
    }
    return 'Jonas S';
  }

  double _extractReviewRating(dynamic review) {
    if (review is Map) {
      final r = review['rating'] ?? review['stars'] ?? review['score'];
      if (r is num) return r.toDouble();
    }
    return 5.0;
  }
}
