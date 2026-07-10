import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/avatar_image.dart';

class CloudmoodHomeScreen extends StatefulWidget {
  final VoidCallback onProfileTap;

  const CloudmoodHomeScreen({super.key, required this.onProfileTap});

  @override
  State<CloudmoodHomeScreen> createState() => _CloudmoodHomeScreenState();
}

class _CloudmoodHomeScreenState extends State<CloudmoodHomeScreen> {
  String _selectedMood = "🏖️ Thư giãn";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sticky App Bar ───────────────────────────────────────
          SliverAppBar(
            pinned: false,
            floating: true,
            snap: true,
            backgroundColor: AppTheme.background,
            elevation: 0,
            toolbarHeight: 64,
            title: HeaderWidget(onProfileTap: widget.onProfileTap),
            titleSpacing: 0,
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero Search Header
                const SearchHeaderWidget(),
                const SizedBox(height: 20),

                // 2. Mood Selector
                MoodSelectorWidget(
                  selectedMood: _selectedMood,
                  onMoodSelected: (mood) {
                    setState(() {
                      _selectedMood = mood;
                    });
                  },
                ),
                const SizedBox(height: 28),

                // 3. Featured Guides
                const FeaturedGuidesSection(),
                const SizedBox(height: 28),

                // 4. Weekend Trips
                const WeekendTripsSection(),
                const SizedBox(height: 28),

                // 5. Popular Destinations
                const PopularDestinationsSection(),

                // Bottom padding for floating nav
                const SizedBox(height: 110),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header Widget with Logo Image, Avatar and Actions
class HeaderWidget extends StatelessWidget {
  final VoidCallback onProfileTap;
  const HeaderWidget({super.key, required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/logo-cloudmood-new.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              const Text('cloudmood', style: AppTheme.brandLogoStyle),
            ],
          ),
          // Right
          Row(
            children: [
              // PRO badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF3CD), Color(0xFFFFE48A)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.amber.withAlpha(80),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star_rounded, color: AppTheme.amber, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Avatar
              ValueListenableBuilder(
                valueListenable: authService.currentUser,
                builder: (context, user, child) {
                  return GestureDetector(
                    onTap: onProfileTap,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: user != null
                            ? AppTheme.primaryGradient
                            : null,
                        color: user != null ? null : AppTheme.surfaceVariant,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withAlpha(30),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: ClipOval(
                          child: Container(
                            color: Colors.white,
                            child: AvatarImage(
                              avatarUrl: user?.avatar,
                              size: 35,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Welcome text and search bar section
class SearchHeaderWidget extends StatelessWidget {
  const SearchHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hôm nay tâm trạng bạn thế nào?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.subtitleText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lên lịch trình\ntheo cảm xúc ✨',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkText,
              letterSpacing: -0.8,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          // Search box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withAlpha(12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
              border: Border.all(color: AppTheme.border, width: 1),
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
                    'Tìm điểm đến, cẩm nang du lịch...',
                    style: TextStyle(color: AppTheme.hintText, fontSize: 14),
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
        ],
      ),
    );
  }
}

/// Mood Selector Widget
class MoodSelectorWidget extends StatelessWidget {
  final String selectedMood;
  final ValueChanged<String> onMoodSelected;

  const MoodSelectorWidget({
    super.key,
    required this.selectedMood,
    required this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> moods = [
      {'icon': '🏖️', 'label': 'Thư giãn'},
      {'icon': '⛰️', 'label': 'Phiêu lưu'},
      {'icon': '🍲', 'label': 'Ẩm thực'},
      {'icon': '🏛️', 'label': 'Khám phá'},
      {'icon': '💆', 'label': 'Nghỉ dưỡng'},
      {'icon': '🛍️', 'label': 'Mua sắm'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text(
                'Tâm trạng hôm nay',
                style: AppTheme.sectionTitleStyle,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Mới',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: moods.length,
            itemBuilder: (context, index) {
              final mood = moods[index];
              final moodString = '${mood['icon']} ${mood['label']}';
              final isSelected = selectedMood == moodString;

              return GestureDetector(
                onTap: () => onMoodSelected(moodString),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.primaryGradient : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppTheme.primary.withAlpha(70)
                            : Colors.black.withAlpha(8),
                        blurRadius: isSelected ? 12 : 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(
                      color: isSelected ? Colors.transparent : AppTheme.border,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(mood['icon']!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        mood['label']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? Colors.white : AppTheme.bodyText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Featured Guides Section
class FeaturedGuidesSection extends StatelessWidget {
  const FeaturedGuidesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> guides = [
      {
        'image':
            'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=600&auto=format&fit=crop&q=80',
        'title': 'Where You Go on Wednesday in Bali',
        'desc':
            'Having spent the past six years exploring Bali, I\'ve developed a deep appreciation for its hidden gems and vibrant culture...',
        'author': 'Bali',
        'views': '76 lượt xem',
        'rating': '4.9',
        'category': 'Cẩm nang',
        'avatar':
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&auto=format&fit=crop&q=80',
      },
      {
        'image':
            'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=600&auto=format&fit=crop&q=80',
        'title': 'What Happens in Bali on Wednesday: Best Places to Be',
        'desc':
            'Lived in Bali for the past decade, capturing the finest sunset viewpoints and local hotspots...',
        'author': 'Bali',
        'views': '71 lượt xem',
        'rating': '4.7',
        'category': 'Gợi ý',
        'avatar':
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&auto=format&fit=crop&q=80',
      },
      {
        'image':
            'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=600&auto=format&fit=crop&q=80',
        'title': 'Ultimate 3-Day Itinerary for First-Timers in Singapore',
        'desc':
            'From Marina Bay Sands to hidden food stalls, discover how to spend your weekend in the lion city...',
        'author': 'Singapore Guide',
        'views': '124 lượt xem',
        'rating': '4.8',
        'category': 'Hành trình',
        'avatar':
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&auto=format&fit=crop&q=80',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hướng dẫn nổi bật',
                style: AppTheme.sectionTitleStyle,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Xem thêm →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: guides.length,
            itemBuilder: (context, index) {
              final guide = guides[index];
              return Container(
                width: 265,
                margin: const EdgeInsets.only(right: 16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withAlpha(15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: AppTheme.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image with overlay badges
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22),
                          ),
                          child: Image.network(
                            guide['image']!,
                            height: 155,
                            width: 265,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 155,
                                color: AppTheme.surfaceVariant,
                                child: const Icon(
                                  Icons.image_rounded,
                                  color: AppTheme.hintText,
                                  size: 40,
                                ),
                              );
                            },
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
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(0),
                              ),
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
                        // Category badge
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              guide['category']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        // Rating
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(130),
                              borderRadius: BorderRadius.circular(10),
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
                                  guide['rating']!,
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
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guide['title']!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkText,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            guide['desc']!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.subtitleText,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  guide['avatar']!,
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 14,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${guide['author']} · ${guide['views']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.subtitleText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.bookmark_border_rounded,
                                  color: AppTheme.primary,
                                  size: 14,
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
  }
}

/// Weekend Trips Section
class WeekendTripsSection extends StatelessWidget {
  const WeekendTripsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> trips = [
      {
        'name': 'Singapore',
        'tag': '2 ngày',
        'image':
            'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=400&auto=format&fit=crop&q=80',
      },
      {
        'name': 'Johor Bahru',
        'tag': '1 ngày',
        'image':
            'https://images.unsplash.com/photo-1626544827763-d516dce335e2?w=400&auto=format&fit=crop&q=80',
      },
      {
        'name': 'Kuala Lumpur',
        'tag': '3 ngày',
        'image':
            'https://images.unsplash.com/photo-1590001155093-a3c66ab0c3ff?w=400&auto=format&fit=crop&q=80',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chuyến đi cuối tuần',
                style: AppTheme.sectionTitleStyle,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Xem thêm →',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 185,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12.0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22.0),
                      child: Image.network(
                        trip['image']!,
                        height: 185,
                        width: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 185,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(
                              Icons.map_rounded,
                              color: Colors.white54,
                              size: 36,
                            ),
                          );
                        },
                      ),
                    ),
                    // Dark gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22.0),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withAlpha(30),
                              Colors.black.withAlpha(180),
                            ],
                            stops: const [0.4, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Tag chip
                    Positioned(
                      top: 12,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(220),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          trip['tag']!,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                    ),
                    // Destination name
                    Positioned(
                      bottom: 14,
                      left: 12,
                      right: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip['name']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
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
  }
}

/// Popular Destinations Section
class PopularDestinationsSection extends StatelessWidget {
  const PopularDestinationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService().fetchPlaces(categoryName: 'Điểm đến'),
      builder: (context, snapshot) {
        final List<Map<String, dynamic>> destinations = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting &&
            destinations.isEmpty) {
          return const SizedBox(
            height: 140,
            child: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        final displayList = destinations.isNotEmpty
            ? destinations
            : [
                {
                  'name': 'Đà Nẵng',
                  'tag': '⭐ 4.9',
                  'image':
                      'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=400&auto=format&fit=crop&q=80',
                },
                {
                  'name': 'Hội An',
                  'tag': '⭐ 4.8',
                  'image':
                      'https://images.unsplash.com/photo-1528127269322-539801943592?w=400&auto=format&fit=crop&q=80',
                },
                {
                  'name': 'Nha Trang',
                  'tag': '⭐ 4.7',
                  'image':
                      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&auto=format&fit=crop&q=80',
                },
                {
                  'name': 'Đà Lạt',
                  'tag': '⭐ 4.9',
                  'image':
                      'https://images.unsplash.com/photo-1583244532610-2a234e7c3eca?w=400&auto=format&fit=crop&q=80',
                },
              ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Điểm đến phổ biến',
                style: AppTheme.sectionTitleStyle,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final dest = displayList[index];
                  return Container(
                    width: 155,
                    margin: const EdgeInsets.only(right: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withAlpha(10),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: AppTheme.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          child: Image.network(
                            dest['image'] ?? '',
                            height: 95,
                            width: 155,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 95,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.accentGradient,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white70,
                                  size: 32,
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  dest['name'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                              ),
                              if (dest['tag'] != null)
                                Text(
                                  dest['tag'] as String,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.amber,
                                  ),
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
    );
  }
}

/// Create Menu Overlay Widget (blur frosted selection menu)
class CreateMenuOverlay extends StatelessWidget {
  final double animationValue;

  const CreateMenuOverlay({super.key, required this.animationValue});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> templates = [
      {
        'title': 'Đà Lạt Mộng Mơ 3N2Đ',
        'mood': '🏖️ Thư giãn',
        'duration': '3 ngày',
        'image':
            'https://images.unsplash.com/photo-1583244532610-2a234e7c3eca?w=200&auto=format&fit=crop&q=80',
      },
      {
        'title': 'Chinh Phục Mã Pí Lèng',
        'mood': '⛰️ Phiêu lưu',
        'duration': '4 ngày',
        'image':
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=200&auto=format&fit=crop&q=80',
      },
      {
        'title': 'Bản Đồ Food Tour Hội An',
        'mood': '🍲 Ẩm thực',
        'duration': '2 ngày',
        'image':
            'https://images.unsplash.com/photo-1528127269322-539801943592?w=200&auto=format&fit=crop&q=80',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryContainer.withAlpha(200),
                      Colors.white.withAlpha(230),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: AppTheme.darkText,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BẮT ĐẦU TRẢI NGHIỆM MỚI',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Hôm nay bạn muốn\nbắt đầu điều gì?',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.darkText,
                                  letterSpacing: -0.8,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Column(
                            children: [
                              _buildOverlayCard(
                                context: context,
                                icon: Icons.luggage_rounded,
                                gradient: AppTheme.primaryGradient,
                                title: 'Lên kế hoạch chuyến đi',
                                subtitle:
                                    'Tạo hành trình thông minh, tự động sắp xếp theo sở thích và tâm trạng của riêng bạn.',
                                actionText: 'Tạo kế hoạch →',
                                actionColor: AppTheme.primary,
                                onTap: () {
                                  Navigator.of(context).pop('create_itinerary');
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildOverlayCard(
                                context: context,
                                icon: Icons.explore_rounded,
                                gradient: AppTheme.accentGradient,
                                title: 'Viết hướng dẫn du lịch',
                                subtitle:
                                    'Chia sẻ địa điểm ẩn mình, cẩm nang chi tiết và mẹo hay cho các lữ khách khác.',
                                actionText: 'Viết cẩm nang →',
                                actionColor: AppTheme.accent,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Mở màn hình soạn thảo cẩm nang du lịch...',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Quick templates section
                Container(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(190),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    border: Border.all(
                      color: Colors.white.withAlpha(200),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.lightAmber,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.bolt_rounded,
                                color: AppTheme.amber,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Bắt đầu nhanh với mẫu có sẵn',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 95,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          itemCount: templates.length,
                          itemBuilder: (context, index) {
                            final tmpl = templates[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Đang tải mẫu: ${tmpl['title']}',
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 225,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(10),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: AppTheme.border,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        tmpl['image']!,
                                        width: 60,
                                        height: 75,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          width: 60,
                                          height: 75,
                                          decoration: BoxDecoration(
                                            gradient: AppTheme.primaryGradient,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tmpl['title']!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.darkText,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              tmpl['mood']!,
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.bodyText,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            tmpl['duration']!,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.subtitleText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayCard({
    required BuildContext context,
    required IconData icon,
    required LinearGradient gradient,
    required String title,
    required String subtitle,
    required String actionText,
    required Color actionColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.subtitleText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    actionText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: actionColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Legacy alias — used by home_screen itself (old code references)
// ignore: unused_element
class _CustomBottomNavBarLegacy extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _CustomBottomNavBarLegacy({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
