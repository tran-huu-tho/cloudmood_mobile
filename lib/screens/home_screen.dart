import 'dart:ui' show ImageFilter;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/api_client.dart';
import '../widgets/avatar_image.dart';
import '../widgets/place_detail_bottom_sheet.dart';

class CloudmoodHomeScreen extends StatefulWidget {
  final VoidCallback onProfileTap;

  const CloudmoodHomeScreen({super.key, required this.onProfileTap});

  @override
  State<CloudmoodHomeScreen> createState() => _CloudmoodHomeScreenState();
}

class _CloudmoodHomeScreenState extends State<CloudmoodHomeScreen> {
  String _selectedMood = "🏖️ Thư giãn";
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = true;
  String _weatherQuote = "";

  @override
  void initState() {
    super.initState();
    _fetchWeatherAndQuote();
  }

  Future<void> _fetchWeatherAndQuote() async {
    setState(() {
      _isLoadingWeather = true;
    });
    try {
      Position? position;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            try {
              position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 5),
              );
            } catch (_) {
              position = await Geolocator.getLastKnownPosition();
            }
          }
        }
      } catch (e) {
        debugPrint('Geolocator error: $e');
      }

      final queryParams = position != null 
          ? {'lat': position.latitude.toString(), 'lon': position.longitude.toString()}
          : {'cityName': 'Da Nang'};

      final response = await ApiClient.get('/weather/current', query: queryParams);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _weatherData = data;
          _weatherQuote = _getQuoteForCondition(data['condition'] ?? '');
        });
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
      }
    }
  }

  String _getQuoteForCondition(String condition) {
    final cond = condition.toLowerCase();
    if (cond.contains('rain') || cond.contains('drizzle') || cond.contains('thunderstorm')) {
      final quotes = [
        "Những ngày mưa là cái cớ hoàn hảo để trốn vào góc quán quen, thưởng thức ly latte ấm và lắng nghe giai điệu Acoustic dịu dàng.",
        "Mưa không làm ta buồn, mưa chỉ làm ta muốn ghé một quán trà nhỏ, ngắm dòng người qua và nghĩ về những hành trình đã qua.",
        "Có những ngày mưa rơi mang theo hương vị của sự bình yên. Một ngày tuyệt vời để tìm cho mình một góc trú chân ấm cúng.",
        "Tiếng mưa tí tách bên hiên nhà là nhạc nền hoàn hảo cho một ngày lười biếng, tận hưởng tách cacao nóng thơm lừng."
      ];
      return (quotes..shuffle()).first;
    } else if (cond.contains('cloud')) {
      final quotes = [
        "Tiết trời dịu mát như chiều lòng người, thích hợp cho một buổi dạo bộ thong dung qua những con hẻm nhỏ bình yên.",
        "Hôm nay trời không nắng gắt, mây nhẹ che đầu, là thời điểm lý tưởng nhất để cùng nhóm bạn thân lên lịch đi trốn.",
        "Bầu trời mang sắc xám nhẹ nhàng, thổi làn gió mát lành gọi mời bước chân ta bước ra ngoài khám phá.",
        "Thời tiết râm mát thế này, một tách trà chiều bên hiên nhà là đủ cho một ngày cuối tuần thảnh thơi."
      ];
      return (quotes..shuffle()).first;
    } else if (cond.contains('clear') || cond.contains('sunny')) {
      final quotes = [
        "Nắng vàng lấp lánh như đang viết nên bài thơ của mùa hè. Hãy xách ba lô lên và đi để không bỏ lỡ ngày xanh!",
        "Bầu trời hôm nay thật trong lành, những tia nắng ấm áp chính là chiếc vé mời gọi ta đến với những vùng đất mới.",
        "Nắng chiếu lung linh qua từng tán lá, một ngày ngập tràn năng lượng thích hợp cho những chuyến đi dã ngoại ngoài trời.",
        "Cuộc đời là những chuyến đi, và nắng hôm nay chính là người bạn đồng hành tuyệt vời nhất của bạn."
      ];
      return (quotes..shuffle()).first;
    } else {
      final quotes = [
        "Dù ngoài trời nắng hay mưa, chỉ cần lòng bạn bình yên thì ngày nào cũng là một ngày đẹp để đi.",
        "Mỗi ngày mới là một chương sách mới. Hãy để thời tiết viết nên những kỷ niệm đáng nhớ trong hành trình của bạn.",
        "Thời tiết đẹp nhất là khi lòng ta sẵn sàng đón nhận những trải nghiệm mới. Khám phá ngay nhé!"
      ];
      return (quotes..shuffle()).first;
    }
  }

  Widget _buildWeatherWidget() {
    if (_isLoadingWeather) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    if (_weatherData == null) {
      return const SizedBox.shrink();
    }

    final temp = _weatherData!['temp'] != null ? (_weatherData!['temp'] as num).round() : 25;
    final cityName = _weatherData!['cityName'] ?? 'Đà Nẵng';
    final desc = _weatherData!['description'] ?? 'Trời mát';
    final iconCode = _weatherData!['icon'] ?? '01d';
    final iconUrl = 'https://openweathermap.org/img/wn/$iconCode@2x.png';
    
    final humidity = _weatherData!['humidity'] ?? 0;
    final windSpeed = _weatherData!['windSpeed'] ?? 0.0;
    
    final suggestions = _weatherData!['suggestions'] ?? {};
    final rainProb = suggestions['rainProbability'] ?? 0;
    final rainfall = suggestions['estimatedRainfall'] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: _fetchWeatherAndQuote,
        child: Container(
          decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primary.withOpacity(0.08),
              AppTheme.primary.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primary.withOpacity(0.12), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.03),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, size: 14, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    cityName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.darkText,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$temp',
                                  style: TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.darkText,
                                    height: 1.0,
                                    letterSpacing: -1,
                                  ),
                                ),
                                Text(
                                  '°C',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.subtitleText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Image.network(
                        iconUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.wb_sunny_rounded,
                          color: AppTheme.primary,
                          size: 48,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricItem(
                        icon: Icons.umbrella_rounded,
                        label: 'Tỷ lệ mưa',
                        value: '$rainProb%',
                      ),
                      _buildMetricItem(
                        icon: Icons.water_drop_rounded,
                        label: 'Lượng mưa',
                        value: rainfall > 0 ? '${rainfall.toStringAsFixed(1)} mm' : '0 mm',
                      ),
                      _buildMetricItem(
                        icon: Icons.opacity_rounded,
                        label: 'Độ ẩm',
                        value: '$humidity%',
                      ),
                      _buildMetricItem(
                        icon: Icons.air_rounded,
                        label: 'Gió',
                        value: '${windSpeed.toStringAsFixed(1)} m/s',
                      ),
                    ],
                  ),

                  if (_weatherQuote.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            size: 20,
                            color: AppTheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _weatherQuote,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 12.5,
                                color: AppTheme.darkText.withOpacity(0.85),
                                height: 1.4,
                              ),
                            ),
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
      ),
    ),
  );
}

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary.withOpacity(0.8)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            color: AppTheme.subtitleText,
          ),
        ),
      ],
    );
  }

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

                // Weather Widget
                _buildWeatherWidget(),
                const SizedBox(height: 24),

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

                // Featured Places Section
                const FeaturedPlacesSection(),
                const SizedBox(height: 28),

                // 3. Featured Guides
                const FeaturedGuidesSection(),

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
            ],
          ),
          // Right
          Row(
            children: [
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
          Text(
            'Hôm nay tâm trạng bạn thế nào?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.subtitleText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
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
              color: AppTheme.surface,
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
                  child: Icon(
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
              Text('Tâm trạng hôm nay', style: AppTheme.sectionTitleStyle),
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
                    color: isSelected ? null : AppTheme.surface,
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
              Text('Hướng dẫn nổi bật', style: AppTheme.sectionTitleStyle),
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
                  color: AppTheme.surface,
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
                                child: Icon(
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
                            style: TextStyle(
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
                            style: TextStyle(
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
                                  style: TextStyle(
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
              Text('Chuyến đi cuối tuần', style: AppTheme.sectionTitleStyle),
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
                          style: TextStyle(
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
            Padding(
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
                      color: AppTheme.surface,
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
                                  style: TextStyle(
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
                                  child: Icon(
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
                        Padding(
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
                                icon: Icons.auto_awesome_rounded,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                title: 'Lên kế hoạch với trợ lý AI',
                                subtitle:
                                    'Trò chuyện cùng Trợ lý AI thông minh để gợi ý địa điểm, lịch trình tối ưu theo ý muốn.',
                                actionText: 'Hỏi Trợ lý AI →',
                                actionColor: const Color(0xFF8E2DE2),
                                onTap: () {
                                  Navigator.of(context).pop('ai_chat');
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildOverlayCard(
                                context: context,
                                icon: Icons.explore_rounded,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF92400E), Color(0xFFD97706)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                title: 'Viết hướng dẫn du lịch',
                                subtitle:
                                    'Chia sẻ địa điểm ẩn mình, cẩm nang chi tiết và mẹo hay cho các lữ khách khác.',
                                actionText: 'Viết cẩm nang →',
                                actionColor: const Color(0xFFD97706),
                                onTap: () {
                                  Navigator.of(context).pop('create_guide');
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
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

/// Featured Places Section
class FeaturedPlacesSection extends StatelessWidget {
  const FeaturedPlacesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService().fetchPlaces(categoryName: 'Nổi bật', limit: 8),
      builder: (context, snapshot) {
        final List<Map<String, dynamic>> places = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting && places.isEmpty) {
          return const SizedBox(
            height: 320,
            child: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (places.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Địa điểm nổi bật',
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: places.length,
                itemBuilder: (context, index) {
                  final place = places[index];
                  final name = place['name'] ?? 'Địa điểm';
                  final image = place['image'] != null && place['image'].isNotEmpty
                      ? place['image']
                      : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&auto=format&fit=crop&q=80';
                  final category = place['category']?['name'] ?? 'Địa điểm';
                  final rating = place['rating'] ?? 4.5;
                  final address = place['address'] ?? '';
                  final desc = place['description'] ?? 'Khám phá địa điểm du lịch tuyệt vời này cùng Cloudmood.';

                  return GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => PlaceDetailBottomSheet(place: place),
                      );
                    },
                    child: Container(
                      width: 265,
                      margin: const EdgeInsets.only(right: 16.0, bottom: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
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
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                                child: Image.network(
                                  image,
                                  height: 155,
                                  width: 265,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 155,
                                    width: 265,
                                    color: AppTheme.surfaceVariant,
                                    child: Icon(Icons.image_not_supported_rounded, color: AppTheme.subtitleText, size: 36),
                                  ),
                                ),
                              ),
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
                                    category,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
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
                                        color: Colors.amber,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        rating is num ? rating.toStringAsFixed(1) : '4.5',
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
                          Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkText,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  desc,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.subtitleText,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_rounded, size: 14, color: AppTheme.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.subtitleText,
                                          fontWeight: FontWeight.w500,
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
              ),
            ),
          ],
        );
      },
    );
  }
}
