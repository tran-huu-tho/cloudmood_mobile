import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class CloudmoodHotelScreen extends StatelessWidget {
  const CloudmoodHotelScreen({super.key});

  void _showWriteReviewDialog(
    BuildContext context,
    int placeId,
    String placeName,
  ) {
    final user = AuthService().currentUser.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để gửi đánh giá!'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    double selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.lightAmber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: AppTheme.amber,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Đánh giá $placeName',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chọn số sao:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.subtitleText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starVal = index + 1;
                      final isSelected = starVal <= selectedRating;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedRating = starVal.toDouble();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isSelected
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppTheme.amber,
                            size: 34,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Chia sẻ cảm nhận của bạn...',
                      prefixIcon: Icons.rate_review_rounded,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(color: AppTheme.subtitleText),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () async {
                    final comment = commentController.text.trim();
                    if (comment.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng nhập bình luận!'),
                        ),
                      );
                      return;
                    }

                    final result = await DatabaseService().createPlaceReview(
                      userId: user.id,
                      placeId: placeId,
                      rating: selectedRating,
                      comment: comment,
                      authorName: user.fullName,
                      authorAvatar: user.avatar ?? '',
                    );

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      if (result != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã gửi đánh giá thành công!'),
                            backgroundColor: AppTheme.green,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Gửi đánh giá'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseService().fetchPlaces(categoryName: 'Khách sạn'),
          builder: (context, snapshot) {
            final List<Map<String, dynamic>> hotels = snapshot.data ?? [];
            final bool isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                hotels.isEmpty;

            final displayList = hotels.isNotEmpty
                ? hotels
                : [
                    {
                      'id': 1,
                      'name': 'The Slate Phuket',
                      'address': 'Phuket, Thái Lan',
                      'rating': 4.9,
                      'price': '3.200.000đ',
                      'image':
                          'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=500&auto=format&fit=crop&q=80',
                      'priceLevel': r'$$$$',
                      'tag': 'Luxury',
                    },
                    {
                      'id': 2,
                      'name': 'Hanging Gardens of Bali',
                      'address': 'Ubud, Bali',
                      'rating': 4.8,
                      'price': '5.800.000đ',
                      'image':
                          'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=500&auto=format&fit=crop&q=80',
                      'priceLevel': r'$$$$$',
                      'tag': 'Best Seller',
                    },
                    {
                      'id': 3,
                      'name': 'Marina Bay Sands',
                      'address': 'Bayfront Avenue, Singapore',
                      'rating': 4.7,
                      'price': '9.100.000đ',
                      'image':
                          'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=500&auto=format&fit=crop&q=80',
                      'priceLevel': r'$$$$$',
                      'tag': 'Iconic',
                    },
                  ];

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NƠI LƯU TRÚ LÝ TƯỞNG',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Khách sạn &\nKhu nghỉ dưỡng',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkText,
                            letterSpacing: -0.8,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Search bar
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
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
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.search_rounded,
                                  color: AppTheme.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Tìm khách sạn, homestay...',
                                  style: TextStyle(
                                    color: AppTheme.hintText,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  color: AppTheme.subtitleText,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Filter chips
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _filterChip('Tất cả', true),
                              _filterChip('Luxury', false),
                              _filterChip('Boutique', false),
                              _filterChip('Resort', false),
                              _filterChip('Homestay', false),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // ── Hotel list ──────────────────────────────────────
                if (isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= displayList.length) return null;
                        final hotel = displayList[index];
                        final placeId = hotel['id'] as int? ?? 1;
                        final addressText =
                            hotel['address'] ?? hotel['location'] ?? '';
                        final priceText = hotel['price'] ?? 'Liên hệ';
                        final ratingVal =
                            (hotel['rating'] as num?)?.toDouble() ?? 5.0;
                        final ratingText = ratingVal.toStringAsFixed(1);
                        final tagText =
                            hotel['tag'] ?? hotel['priceLevel'] ?? 'Hot';

                        // Color for tag
                        Color tagColor = AppTheme.primary;
                        Color tagBg = AppTheme.primaryContainer;
                        if (tagText == 'Best Seller') {
                          tagColor = AppTheme.green;
                          tagBg = AppTheme.lightGreen;
                        } else if (tagText == 'Iconic') {
                          tagColor = const Color(0xFF7C3AED);
                          tagBg = const Color(0xFFEDE9FE);
                        }

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Container(
                            decoration: AppTheme.premiumCardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                      child: Image.network(
                                        hotel['image'] ?? '',
                                        height: 185,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          height: 185,
                                          decoration: const BoxDecoration(
                                            gradient: AppTheme.primaryGradient,
                                            borderRadius:
                                                BorderRadius.vertical(
                                              top: Radius.circular(20),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.hotel_rounded,
                                            color: Colors.white54,
                                            size: 48,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Gradient overlay
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      height: 70,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withAlpha(100),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Tag
                                    Positioned(
                                      top: 14,
                                      left: 14,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tagBg,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          tagText,
                                          style: TextStyle(
                                            color: tagColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Rating
                                    Positioned(
                                      top: 14,
                                      right: 14,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(140),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.star_rounded,
                                              color: AppTheme.amber,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              ratingText,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Content
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hotel['name'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.darkText,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_rounded,
                                            color: AppTheme.subtitleText,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              addressText,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppTheme.subtitleText,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      // Price row
                                      Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Giá từ / đêm',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.subtitleText,
                                                ),
                                              ),
                                              Text(
                                                priceText,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppTheme.primary,
                                                  letterSpacing: -0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Actions row
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.primary,
                                              side: const BorderSide(
                                                color: AppTheme.border,
                                                width: 1.5,
                                              ),
                                              shape:
                                                  RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12),
                                              ),
                                              minimumSize: Size.zero,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                            onPressed: () =>
                                                _showWriteReviewDialog(
                                              context,
                                              placeId,
                                              hotel['name'] ?? 'Khách sạn',
                                            ),
                                            child: const Text(
                                              'Đánh giá',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          GestureDetector(
                                            onTap: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Đang kết nối đặt phòng ${hotel['name']}...',
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                              decoration:
                                                  AppTheme.gradientButtonDecoration(
                                                radius: 12,
                                              ),
                                              child: const Text(
                                                'Đặt phòng',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
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
                        );
                      },
                      childCount: displayList.length,
                    ),
                  ),
                // Bottom padding for floating nav
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isSelected ? AppTheme.primaryGradient : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.transparent : AppTheme.border,
          width: 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppTheme.primary.withAlpha(60),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : AppTheme.bodyText,
        ),
      ),
    );
  }
}
