import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CloudmoodDealsScreen extends StatelessWidget {
  const CloudmoodDealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> deals = [
      {
        'title': 'Ưu đãi bay giảm 20%',
        'code': 'CLOUDMOVE20',
        'desc':
            'Giảm ngay 20% khi đặt vé máy bay khứ hồi nội địa trên ứng dụng.',
        'expiry': '31/12/2026',
        'image':
            'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=500&auto=format&fit=crop&q=80',
        'category': 'VÉ MÁY BAY',
        'badge': '20%',
      },
      {
        'title': 'Combo Phú Quốc Trọn Gói',
        'code': 'PHUQUOC3N2D',
        'desc': 'Vé máy bay + Khách sạn 5 sao chỉ từ 3.890.000đ/người.',
        'expiry': '15/10/2026',
        'image':
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&auto=format&fit=crop&q=80',
        'category': 'COMBO TOUR',
        'badge': 'HOT',
      },
      {
        'title': 'Mã giảm ẩm thực Đà Nẵng',
        'code': 'DANANGFOOD',
        'desc':
            'Giảm 50.000đ cho hóa đơn từ 300.000đ tại các nhà hàng đối tác.',
        'expiry': 'Hết hạn hôm nay',
        'image':
            'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=500&auto=format&fit=crop&q=80',
        'category': 'ẨM THỰC',
        'badge': '-50k',
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ƯU ĐÃI ĐỘC QUYỀN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mã Giảm Giá &\nƯu Đãi Chuyến Đi',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkText,
                        letterSpacing: -0.8,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Promo banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.local_offer_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Thành viên PRO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Nhận thêm nhiều ưu đãi độc quyền',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Nâng cấp',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Deals list ──────────────────────────────────────────
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= deals.length) return null;
                  final deal = deals[index];

                  // Category color mapping
                  Color catColor = AppTheme.primary;
                  Color catBg = AppTheme.primaryContainer;
                  IconData catIcon = Icons.local_offer_rounded;
                  if (deal['category'] == 'COMBO TOUR') {
                    catColor = AppTheme.green;
                    catBg = AppTheme.lightGreen;
                    catIcon = Icons.luggage_rounded;
                  } else if (deal['category'] == 'ẨM THỰC') {
                    catColor = AppTheme.amber;
                    catBg = AppTheme.lightAmber;
                    catIcon = Icons.restaurant_rounded;
                  }

                  final bool isExpiring =
                      deal['expiry']?.contains('hôm nay') == true;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      decoration: AppTheme.premiumCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image with overlay
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                child: Image.network(
                                  deal['image']!,
                                  height: 145,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    height: 145,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius:
                                          const BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Gradient overlay
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 60,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withAlpha(80),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Badge
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: catBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    deal['badge']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: catColor,
                                    ),
                                  ),
                                ),
                              ),
                              if (isExpiring)
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '⏰ Sắp hết hạn',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: catBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        catIcon,
                                        color: catColor,
                                        size: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      deal['category']!,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: catColor,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  deal['title']!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.darkText,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  deal['desc']!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.subtitleText,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // Code row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Code chip
                                    GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Đã sao chép: ${deal['code']}',
                                            ),
                                            backgroundColor: AppTheme.green,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: AppTheme.primary
                                                .withAlpha(50),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.confirmation_num_rounded,
                                              color: AppTheme.primary,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              deal['code']!,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.primary,
                                                fontSize: 13,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.copy_rounded,
                                              color: AppTheme.primary,
                                              size: 12,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Expiry
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          size: 12,
                                          color: isExpiring
                                              ? AppTheme.red
                                              : AppTheme.subtitleText,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          deal['expiry']!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isExpiring
                                                ? AppTheme.red
                                                : AppTheme.subtitleText,
                                            fontWeight: isExpiring
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ],
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
                childCount: deals.length,
              ),
            ),
            // Bottom padding for floating nav
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}
