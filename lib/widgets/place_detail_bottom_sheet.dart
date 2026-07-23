import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../utils/time_utils.dart';
import '../utils/string_utils.dart';
import '../services/auth_service.dart';
import 'save_to_trip_bottom_sheet.dart';
import '../screens/place_ai_chat_screen.dart';

class PlaceDetailBottomSheet extends StatefulWidget {
  final Map<String, dynamic> place;
  final IconData? overrideIcon;
  final Color? overrideColor;
  final String? overrideText;
  final Map<String, dynamic>? currentItinerary;
  final int savedCount;
  final VoidCallback? onTripUpdated;

  const PlaceDetailBottomSheet({
    super.key,
    required this.place,
    this.overrideIcon,
    this.overrideColor,
    this.overrideText,
    this.currentItinerary,
    this.savedCount = 0,
    this.onTripUpdated,
  });

  static void show(
    BuildContext context,
    Map<String, dynamic> place, {
    IconData? icon,
    Color? color,
    String? text,
    Map<String, dynamic>? currentItinerary,
    int savedCount = 0,
    VoidCallback? onTripUpdated,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: PlaceDetailBottomSheet(
            place: place,
            overrideIcon: icon,
            overrideColor: color,
            overrideText: text,
            currentItinerary: currentItinerary,
            savedCount: savedCount,
            onTripUpdated: onTripUpdated,
          ),
        ),
      ),
    );
  }

  @override
  State<PlaceDetailBottomSheet> createState() => _PlaceDetailBottomSheetState();
}

class _PlaceDetailBottomSheetState extends State<PlaceDetailBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;
  late int _localSavedCount;

  @override
  void initState() {
    super.initState();
    _localSavedCount = widget.savedCount;
    _tabController = TabController(length: 3, vsync: this);
    _loadReviews();
    _refreshSavedCount();
  }

  Future<void> _loadReviews() async {
    final rawId = widget.place['id'];
    if (rawId != null) {
      final placeId = int.tryParse(rawId.toString());
      if (placeId != null) {
        final reviews = await DatabaseService().fetchPlaceReviews(placeId);
        if (mounted) {
          setState(() {
            _reviews = reviews;
            _isLoadingReviews = false;
          });
        }
        return;
      }
    }
    if (mounted) {
      setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _refreshSavedCount() async {
    final user = AuthService().currentUser.value;
    if (user != null) {
      final trips = await DatabaseService().fetchUserItineraries(
        int.parse(user.id.toString()),
        isGuide: false,
      );
      if (mounted) {
        int tripsCount = 0;
        final targetId = widget.place['id'];

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

        setState(() {
          _localSavedCount = tripsCount;
        });
      }
    }
  }

  Future<void> _launchURL(Uri url) async {
    try {
      await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      try {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } catch (ex) {
        debugPrint('Error launching URL: $ex');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    IconData? categoryIcon = widget.overrideIcon;
    Color categoryColor = widget.overrideColor ?? const Color(0xFF3B5998);

    if (widget.overrideColor == null &&
        widget.overrideIcon == null &&
        widget.place['category'] != null) {
      final cat = widget.place['category'];
      if (cat['iconCode'] != null) {
        categoryIcon = IconData(cat['iconCode'], fontFamily: 'MaterialIcons');
      }
      if (cat['id'] != null) {
        final List<Color> colors = [
          const Color(0xFF3B5998),
          const Color(0xFFE91E63),
          const Color(0xFF009688),
          const Color(0xFFFF9800),
          const Color(0xFF9C27B0),
          const Color(0xFF4CAF50),
          const Color(0xFFF44336),
          const Color(0xFF673AB7),
          const Color(0xFF00BCD4),
        ];
        categoryColor = colors[(cat['id'] as num).toInt() % colors.length];
      }
    }

    return Column(
      children: [
        // Drag Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.only(
            top: 8,
            left: 16,
            right: 16,
            bottom: 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: categoryColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child:
                    widget.overrideText != null &&
                        (categoryIcon == null ||
                            categoryIcon.codePoint ==
                                Icons.looks_one_rounded.codePoint)
                    ? Text(
                        widget.overrideText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      )
                    : Icon(
                        categoryIcon ?? Icons.place,
                        color: Colors.white,
                        size: 16,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.place['name'] ?? '',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.black54,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          dividerColor: Colors.grey[200],
          tabs: const [
            Tab(text: 'Giới thiệu'),
            Tab(text: 'Đánh giá'),
            Tab(text: 'Ảnh'),
          ],
        ),
        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildIntroTab(), _buildReviewsTab(), _buildPhotosTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroTab() {
    final String description =
        widget.place['description'] ?? widget.place['editorialSummary'] ?? '';
    final double rating = (widget.place['rating'] as num?)?.toDouble() ?? 0.0;
    final int userRatingCount =
        (widget.place['userRatingCount'] as num?)?.toInt() ?? 0;
    final String address = StringUtils.cleanAddress(
      widget.place['address'] ?? '',
    );

    final String? phone =
        widget.place['phone'] ??
        widget.place['phoneNumber'] ??
        widget.place['internationalPhoneNumber'] ??
        widget.place['nationalPhoneNumber'] ??
        widget.place['contactPhone'];
    final String? website =
        widget.place['website'] ??
        widget.place['websiteUri'] ??
        widget.place['webUrl'] ??
        widget.place['websiteUrl'];
    final String? price = widget.place['price'];
    final String? priceLevel = widget.place['priceLevel'];

    String? openingHours;
    final hoursRaw =
        widget.place['regularOpeningHours'] ?? widget.place['openingHours'];
    if (hoursRaw != null) {
      openingHours = TimeUtils.getOpeningHoursText(hoursRaw);
    }

    final cat = widget.place['category'];
    final String? mainCategory = cat != null && cat['name'] != null
        ? cat['name'].toString()
        : null;

    final List<String> amenities = [];
    final rawSub =
        widget.place['subCategories'] ??
        widget.place['subcategories'] ??
        widget.place['sub_categories'];
    if (rawSub is List) {
      amenities.addAll(rawSub.map((e) => e.toString()));
    }

    String? imageUrl;
    if (widget.place['image'] != null &&
        widget.place['image'].toString().isNotEmpty) {
      imageUrl = widget.place['image'];
    } else if (widget.place['photos'] != null &&
        widget.place['photos'] is List &&
        widget.place['photos'].isNotEmpty) {
      final p = widget.place['photos'][0];
      if (p is Map) {
        imageUrl = p['urlOriginal'] ?? p['urlThumbnail'] ?? p['url'];
      } else {
        imageUrl = p.toString();
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description and Image
          if (description.isNotEmpty || imageUrl != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    description.isNotEmpty
                        ? 'Mô tả: $description'
                        : 'Địa điểm này chưa có mô tả chi tiết.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontStyle: description.isNotEmpty
                          ? FontStyle.normal
                          : FontStyle.italic,
                      color: description.isNotEmpty
                          ? Colors.black87
                          : Colors.grey[600],
                    ),
                  ),
                ),
                if (imageUrl != null) ...[
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          (imageUrl.startsWith('data:image/') &&
                              imageUrl.contains('base64,'))
                          ? Image.memory(
                              base64Decode(imageUrl.split('base64,').last),
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            )
                          : Image.network(
                              imageUrl,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 16),
          // Action Buttons Row (Save & Hỏi AI)
          Row(
            children: [
              _localSavedCount > 0
                  ? _buildActionButton(
                      Icons.bookmark,
                      'Đã thêm vào $_localSavedCount chuyến đi',
                      Colors.grey[200]!,
                      Colors.black,
                      suffixIcon: Icons.keyboard_arrow_down,
                      onTap: () async {
                        // User can be saving to different trips, no longer strictly bounded to currentItinerary
                        await SaveToTripBottomSheet.show(
                          context,
                          widget.place,
                          onSaved: widget.onTripUpdated ?? () {},
                          initialItinerary: widget.currentItinerary,
                        );
                        _refreshSavedCount();
                      },
                    )
                  : _buildActionButton(
                      Icons.bookmark_border,
                      'Thêm vào chuyến đi',
                      AppTheme.primary,
                      Colors.white,
                      onTap: () async {
                        await SaveToTripBottomSheet.show(
                          context,
                          widget.place,
                          onSaved: widget.onTripUpdated ?? () {},
                          initialItinerary: widget.currentItinerary,
                        );
                        _refreshSavedCount();
                      },
                    ),
              const SizedBox(width: 8),
              _buildActionButton(
                Icons.search,
                'Hỏi AI',
                Colors.red[50]!,
                Colors.red,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaceAIChatScreen(
                        placeName: widget.place['name'] ?? 'Địa điểm',
                        placeInfo: widget.place,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tags (Category & Amenities)
          if (mainCategory != null) ...[
            const Text(
              'Danh mục:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildTag(mainCategory.toString()),
            const SizedBox(height: 16),
          ],
          if (amenities.isNotEmpty) ...[
            const Text(
              'Tiện ích:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...amenities.map(
                  (t) => _buildTag(t.toString(), isAmenity: true),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // Rating, Mentions, Address
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Text(
                '$rating ($userRatingCount)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/images/tripadvisor.jpg',
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.trip_origin,
                    color: Colors.green,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Info Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final url = Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.place['name'] ?? address)}',
                          );
                          await _launchURL(url);
                        },
                        child: Text(
                          address,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: address));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép địa chỉ')),
                        );
                      },
                      child: Icon(
                        Icons.copy_rounded,
                        color: AppTheme.subtitleText,
                        size: 16,
                      ),
                    ),
                  ],
                ),

                // Phone
                if (phone != null && phone.isNotEmpty) ...[
                  const Divider(height: 24, thickness: 1),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final url = Uri.parse('tel:$phone');
                            await _launchURL(url);
                          },
                          child: Text(
                            phone,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Website
                if (website != null && website.isNotEmpty) ...[
                  const Divider(height: 24, thickness: 1),
                  Row(
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final url = Uri.parse(website);
                            await _launchURL(url);
                          },
                          child: Text(
                            website,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Price / Price Level
                if ((price != null && price.isNotEmpty) ||
                    (priceLevel != null && priceLevel.isNotEmpty)) ...[
                  const Divider(height: 24, thickness: 1),
                  Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Mức giá: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          '${price ?? ''}${priceLevel != null && priceLevel.isNotEmpty ? ' (${_formatPriceLevel(priceLevel)})' : ''}',
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (widget.place['openingHours'] != null ||
              widget.place['regularOpeningHours'] != null) ...[
            const SizedBox(height: 12),
            _buildFullOpeningHours(
              widget.place['regularOpeningHours'] ??
                  widget.place['openingHours'],
            ),
          ],
          const SizedBox(height: 24),
          // Open in
          const Text(
            'Mở trong:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildOpenInImageButton(
                'assets/images/googlemap.png',
                'Google Maps',
                () async {
                  final String query =
                      (widget.place['name'] ?? '') +
                      (address.isNotEmpty ? ' ' + address : '');
                  final url = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
                  );
                  await _launchURL(url);
                },
              ),
              _buildOpenInImageButton(
                'assets/images/tripadvisor.jpg',
                'Tripadvisor',
                () async {
                  final String? urlString = widget.place['tripadvisorUrl'];
                  final String suffix =
                      address.toLowerCase().contains('cần thơ')
                      ? ' Cần Thơ'
                      : '';
                  final String query = (widget.place['name'] ?? '') + suffix;
                  final url = Uri.parse(
                    (urlString != null && urlString.isNotEmpty)
                        ? urlString
                        : 'https://www.tripadvisor.com/Search?q=${Uri.encodeComponent(query)}',
                  );
                  await _launchURL(url);
                },
              ),
              _buildOpenInImageButton(
                'assets/images/google.png',
                'Google',
                () async {
                  final String suffix =
                      address.toLowerCase().contains('cần thơ')
                      ? ' Cần Thơ'
                      : '';
                  final String query =
                      (widget.place['name'] ?? '') + suffix + ' wikipedia';
                  final url = Uri.parse(
                    'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
                  );
                  await _launchURL(url);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Highlighted Reviews
          const Text(
            'Đánh giá nổi bật',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (_isLoadingReviews)
            const Center(child: CircularProgressIndicator())
          else if (_reviews.isEmpty)
            const Text('Chưa có đánh giá nào')
          else
            ..._reviews.take(2).map((r) => _buildReviewCard(r)),
          if (_reviews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton(
                onPressed: () {
                  _tabController.animateTo(1);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Xem tất cả đánh giá'),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    final double rating = (widget.place['rating'] as num?)?.toDouble() ?? 4.2;
    final int userRatingCount =
        (widget.place['userRatingCount'] as num?)?.toInt() ?? 156;

    // Phân bổ sao dựa trên điểm trung bình thực tế
    int count5 = 0;
    int count4 = 0;
    int count3 = 0;
    int count2 = 0;
    int count1 = 0;

    if (userRatingCount > 0) {
      if (rating >= 4.9) {
        count5 = userRatingCount;
      } else if (rating <= 1.1) {
        count1 = userRatingCount;
      } else {
        double w5 = rating >= 4.0 ? (rating - 3.0) : 0.1;
        double w4 = rating >= 3.0 ? (3.5 - (rating - 4.0).abs()) : 0.2;
        double w3 = 1.5 - (rating - 3.0).abs();
        double w2 = rating <= 4.0 ? (3.0 - rating) : 0.05;
        double w1 = rating <= 3.0 ? (2.5 - rating) : 0.02;

        if (w5 < 0) w5 = 0.01;
        if (w4 < 0) w4 = 0.01;
        if (w3 < 0) w3 = 0.01;
        if (w2 < 0) w2 = 0.01;
        if (w1 < 0) w1 = 0.01;

        double sumW = w5 + w4 + w3 + w2 + w1;

        count5 = ((w5 / sumW) * userRatingCount).round();
        count4 = ((w4 / sumW) * userRatingCount).round();
        count3 = ((w3 / sumW) * userRatingCount).round();
        count2 = ((w2 / sumW) * userRatingCount).round();
        count1 = userRatingCount - count5 - count4 - count3 - count2;

        if (count1 < 0) {
          count5 += count1;
          count1 = 0;
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tripadvisor Rating Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2B3246), Color(0xFF1E2332)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2B3246).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'trên 5',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating >= 4.5
                            ? 'Tuyệt vời'
                            : (rating >= 4.0
                                  ? 'Rất tốt'
                                  : (rating >= 3.0 ? 'Khá tốt' : 'Trung bình')),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$userRatingCount đánh giá',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              'assets/images/tripadvisor.jpg',
                              width: 16,
                              height: 16,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.circle,
                                size: 16,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Từ Tripadvisor',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
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
          const SizedBox(height: 24),

          // Rating Bars
          _buildRatingBar(
            '5 sao',
            count5,
            userRatingCount,
            const Color(0xFFF9A826),
          ),
          _buildRatingBar(
            '4 sao',
            count4,
            userRatingCount,
            const Color(0xFFF9A826),
          ),
          _buildRatingBar(
            '3 sao',
            count3,
            userRatingCount,
            const Color(0xFFF9A826),
          ),
          _buildRatingBar(
            '2 sao',
            count2,
            userRatingCount,
            const Color(0xFFE0E0E0),
          ),
          _buildRatingBar(
            '1 sao',
            count1,
            userRatingCount,
            const Color(0xFFE0E0E0),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Reviews List
          if (_isLoadingReviews)
            const Center(child: CircularProgressIndicator())
          else if (_reviews.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Chưa có đánh giá nào',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._reviews.map((r) => _buildReviewCard(r)),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final String? urlString = widget.place['tripadvisorUrl'];
                if (urlString != null && urlString.isNotEmpty) {
                  final url = Uri.parse(urlString);
                  if (await canLaunchUrl(url)) await launchUrl(url);
                }
              },
              icon: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/tripadvisor.jpg',
                  width: 24,
                  height: 24,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.open_in_browser, size: 24),
                ),
              ),
              label: const Text(
                'Đánh giá trên Tripadvisor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF3F4F6),
                foregroundColor: AppTheme.darkText,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String label, int count, int total, Color color) {
    final double percent = total > 0 ? (count / total) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 45,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.darkText,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percent,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 35,
            child: Text(
              count.toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosTab() {
    List<dynamic> photos = [];
    if (widget.place['photos'] != null && widget.place['photos'] is List) {
      photos = List.from(widget.place['photos']);
    }

    if (photos.isEmpty) return const Center(child: Text('Chưa có ảnh nào'));

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        String photoUrl = '';
        final p = photos[index];
        if (p is Map) {
          photoUrl = p['urlOriginal'] ?? p['urlThumbnail'] ?? p['url'] ?? '';
        } else {
          photoUrl = p.toString();
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color bgColor,
    Color textColor, {
    Color? borderColor,
    VoidCallback? onTap,
    IconData? suffixIcon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            border: borderColor != null ? Border.all(color: borderColor) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: textColor),
              if (label.isNotEmpty) const SizedBox(width: 6),
              if (label.isNotEmpty)
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              if (suffixIcon != null) ...[
                const SizedBox(width: 4),
                Icon(suffixIcon, size: 18, color: textColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, {bool isAmenity = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isAmenity ? AppTheme.accentLight : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAmenity
              ? AppTheme.accent.withOpacity(0.3)
              : Colors.grey[200]!,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isAmenity ? AppTheme.primaryDark : Colors.black87,
        ),
      ),
    );
  }

  String _formatPriceLevel(String level) {
    switch (level.toUpperCase()) {
      case 'CHEAP':
      case 'INEXPENSIVE':
        return 'Giá rẻ';
      case 'MODERATE':
        return 'Trung bình';
      case 'EXPENSIVE':
        return 'Sang trọng';
      case 'VERY_EXPENSIVE':
        return 'Rất sang trọng';
      case 'FREE':
        return 'Miễn phí';
      default:
        return level;
    }
  }

  Widget _buildOpenInButton(
    IconData icon,
    String label,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenInImageButton(
    String imagePath,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              imagePath,
              width: 16,
              height: 16,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(Icons.link, size: 16),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberedListItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB8A9E6),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: const TextStyle(height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconListItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final String authorName = review['authorName'] ?? 'Người dùng Tripadvisor';
    final String? authorPhoto =
        review['authorAvatar'] ??
        review['authorPhotoUrl'] ??
        review['profilePhotoUrl'];

    String dateString = 'Nổi bật';
    if (review['createdAt'] != null) {
      try {
        final date = DateTime.parse(review['createdAt']);
        dateString = '${date.day} Thg ${date.month} ${date.year}';
      } catch (e) {
        // ignore
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[200],
                backgroundImage: authorPhoto != null && authorPhoto.isNotEmpty
                    ? NetworkImage(authorPhoto)
                    : null,
                child: authorPhoto == null || authorPhoto.isEmpty
                    ? Text(
                        authorName.isNotEmpty
                            ? authorName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.darkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '$dateString ',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        const Text(
                          'từ Tripadvisor ',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            'assets/images/tripadvisor.jpg',
                            width: 14,
                            height: 14,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review['comment'] ?? '',
            style: const TextStyle(
              color: Colors.black87,
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullOpeningHours(dynamic hoursData) {
    if (hoursData == null) return const SizedBox.shrink();

    final schedule = TimeUtils.getFullWeekSchedule(hoursData);
    if (schedule.isEmpty) {
      final hoursText = TimeUtils.getOpeningHoursText(hoursData);
      if (hoursText.isEmpty) return const SizedBox.shrink();

      final isClosed = hoursText.toLowerCase().contains('đóng cửa');
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.access_time_rounded, color: Colors.grey, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hoursText,
              style: TextStyle(
                color: isClosed ? Colors.red : Colors.black87,
                fontWeight: isClosed ? FontWeight.w600 : FontWeight.normal,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.access_time_rounded, color: Colors.grey, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: schedule.map((day) {
                  final isToday = day['isToday'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isToday
                                ? Colors.blueAccent
                                : Colors.blueAccent.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            day['shortName'] ?? '',
                            style: TextStyle(
                              color: isToday ? Colors.white : Colors.blueAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${day['dayName']}: ${day['time']}',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  day['time'].toString().toLowerCase().contains(
                                    'đóng cửa',
                                  )
                                  ? Colors.red
                                  : (isToday ? Colors.black87 : Colors.black54),
                              fontWeight:
                                  (isToday ||
                                      day['time']
                                          .toString()
                                          .toLowerCase()
                                          .contains('đóng cửa'))
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
