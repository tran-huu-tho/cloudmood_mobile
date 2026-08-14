import 'dart:ui' show ImageFilter;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/api_client.dart';
import '../widgets/avatar_image.dart';
import '../widgets/place_detail_bottom_sheet.dart';
import 'explore_post_detail_screen.dart';
import 'places_screen.dart';
import 'forum_screen.dart';
import 'all_explore_guides_screen.dart';

class CloudmoodHomeScreen extends StatefulWidget {
  final VoidCallback onProfileTap;
  final Function(String query)? onExplorePlacesTap;
  final VoidCallback? onExploreGuidesTap;

  const CloudmoodHomeScreen({
    super.key,
    required this.onProfileTap,
    this.onExplorePlacesTap,
    this.onExploreGuidesTap,
  });

  @override
  State<CloudmoodHomeScreen> createState() => _CloudmoodHomeScreenState();
}

class _CloudmoodHomeScreenState extends State<CloudmoodHomeScreen> {
  String _selectedMood = "🏖️ Thư giãn";
  Map<String, dynamic>? _weatherData;
  bool _isLoadingWeather = true;
  String? _weatherError;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  static Map<String, dynamic>? _cachedWeatherData;
  static DateTime? _lastWeatherFetchTime;
  Timer? _weatherTimer;

  @override
  void initState() {
    super.initState();
    _fetchWeatherAndQuote();
    _weatherTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _fetchWeatherAndQuote(force: true);
    });
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWeatherAndQuote({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _cachedWeatherData != null &&
        _lastWeatherFetchTime != null &&
        now.difference(_lastWeatherFetchTime!) < const Duration(minutes: 10)) {
      if (mounted) {
        setState(() {
          _weatherData = _cachedWeatherData;
          _weatherError = null;
          _isLoadingWeather = false;
        });
      }
      return;
    }

    if (_cachedWeatherData == null) {
      if (mounted) {
        setState(() {
          _isLoadingWeather = true;
          _weatherError = null;
        });
      }
    }

    try {
      Position? position;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            try {
              position = await Geolocator.getLastKnownPosition();
              if (position == null) {
                position = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.low,
                  timeLimit: const Duration(seconds: 2),
                );
              }
            } catch (_) {
              // Fail-safe
            }
          }
        }
      } catch (e) {
        debugPrint('Geolocator error: $e');
      }

      final queryParams = position != null
          ? {
              'lat': position.latitude.toString(),
              'lon': position.longitude.toString(),
            }
          : {'cityName': 'Can Tho'};

      final response = await ApiClient.get(
        '/weather/current',
        query: queryParams,
        timeout: const Duration(seconds: 25),
      );
      if (response.statusCode == 200) {
        final rawData = Map<String, dynamic>.from(jsonDecode(response.body));
        final initialData = {
          ...rawData,
          'rainDataSource': 'Đang cập nhật Open-Meteo',
        };
        _cachedWeatherData = initialData;
        _lastWeatherFetchTime = DateTime.now();

        if (mounted) {
          setState(() {
            _weatherData = initialData;
            _weatherError = null;
            _isLoadingWeather = false;
          });
        }

        final data = await _attachHourlyRainForecast(initialData);
        _cachedWeatherData = data;
        _lastWeatherFetchTime = DateTime.now();
        if (mounted) {
          setState(() {
            _weatherData = data;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
      if (mounted && _weatherData == null) {
        setState(() {
          _weatherError = 'Không thể cập nhật thời tiết';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _attachHourlyRainForecast(
    Map<String, dynamic> currentData,
  ) async {
    final latitude = (currentData['latitude'] as num?)?.toDouble();
    final longitude = (currentData['longitude'] as num?)?.toDouble();
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite) {
      return {
        ...currentData,
        'rainDataSource': 'Ước tính từ điều kiện hiện tại',
      };
    }

    try {
      final response = await ApiClient.get(
        '/weather/hourly',
        query: {'lat': latitude.toString(), 'lon': longitude.toString()},
        timeout: const Duration(seconds: 10),
      );
      if (response.statusCode != 200) {
        return {
          ...currentData,
          'rainDataSource': 'Ước tính từ điều kiện hiện tại',
        };
      }

      final payload = Map<String, dynamic>.from(jsonDecode(response.body));
      final hourly = payload['hourly'] is Map
          ? Map<String, dynamic>.from(payload['hourly'])
          : <String, dynamic>{};
      final times = List<dynamic>.from(hourly['time'] ?? const []);
      final probabilities = List<dynamic>.from(
        hourly['precipitation_probability'] ?? const [],
      );
      final precipitation = List<dynamic>.from(
        hourly['precipitation'] ?? const [],
      );
      if (times.isEmpty) {
        return {
          ...currentData,
          'rainDataSource': 'Ước tính từ điều kiện hiện tại',
        };
      }

      final now = DateTime.now();
      var nearestIndex = 0;
      var nearestDifference = const Duration(days: 365);
      for (var index = 0; index < times.length; index++) {
        final forecastTime = DateTime.tryParse(times[index].toString());
        if (forecastTime == null) continue;
        final difference = forecastTime.difference(now).abs();
        if (difference < nearestDifference) {
          nearestDifference = difference;
          nearestIndex = index;
        }
      }

      final rainProbability = nearestIndex < probabilities.length
          ? (probabilities[nearestIndex] as num?)?.round()
          : null;
      final rainAmount = nearestIndex < precipitation.length
          ? (precipitation[nearestIndex] as num?)?.toDouble()
          : null;
      final suggestions = currentData['suggestions'] is Map
          ? Map<String, dynamic>.from(currentData['suggestions'])
          : <String, dynamic>{};
      if (rainProbability != null) {
        suggestions['rainProbability'] = rainProbability.clamp(0, 100);
      }
      if (rainAmount != null) {
        suggestions['estimatedRainfall'] = rainAmount;
      }

      return {
        ...currentData,
        'suggestions': suggestions,
        if (rainAmount != null) 'rainfall': rainAmount,
        'rainDataSource': 'Open-Meteo theo giờ',
        'forecastTime': times[nearestIndex].toString(),
      };
    } catch (error) {
      debugPrint(
        'Không thể bổ sung dự báo mưa Open-Meteo: ' + error.toString(),
      );
      return {
        ...currentData,
        'rainDataSource': 'Ước tính từ điều kiện hiện tại',
      };
    }
  }

  String _getFriendlyWeatherDesc(String rawDesc, String condition) {
    final raw = rawDesc.toLowerCase();
    final cond = condition.toLowerCase();

    if (raw.contains('mây đen') ||
        raw.contains('overcast') ||
        raw.contains('broken clouds')) {
      return 'Nhiều mây âm u';
    } else if (raw.contains('scattered') ||
        raw.contains('few clouds') ||
        raw.contains('mây rải rác')) {
      return 'Mây rải rác nhẹ';
    } else if (raw.contains('cloud') || cond.contains('cloud')) {
      return 'Trời nhiều mây';
    } else if (raw.contains('clear') ||
        raw.contains('sunny') ||
        cond.contains('clear')) {
      return 'Trời nắng quang đãng';
    } else if (raw.contains('light rain') ||
        raw.contains('mưa nhẹ') ||
        raw.contains('mưa rào rải rác')) {
      return 'Mưa rào nhẹ';
    } else if (raw.contains('thunderstorm') || cond.contains('thunderstorm')) {
      return 'Mưa giông';
    } else if (raw.contains('rain') || cond.contains('rain')) {
      return 'Có mưa rào';
    } else if (raw.contains('drizzle') || cond.contains('drizzle')) {
      return 'Mưa phùn nhẹ';
    } else if (raw.contains('mist') || raw.contains('fog')) {
      return 'Sương mù nhẹ';
    }
    return rawDesc.isNotEmpty ? rawDesc : 'Trời mát';
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherWidget() {
    if (_isLoadingWeather) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 20,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _weatherError ?? 'Chưa có dữ liệu thời tiết',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _fetchWeatherAndQuote(force: true),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Thử lại'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final temp = _weatherData!['temp'] != null
        ? (_weatherData!['temp'] as num).round()
        : 25;
    final cityName = _weatherData!['cityName'] ?? 'Cần Thơ';
    final rawDesc = _weatherData!['description'] ?? '';
    final condition = _weatherData!['condition'] ?? '';
    final desc = _getFriendlyWeatherDesc(rawDesc, condition);

    final iconCode = _weatherData!['icon'] ?? '01d';
    final iconUrl = 'https://openweathermap.org/img/wn/$iconCode@2x.png';

    final humidity = _weatherData!['humidity'] ?? 0;
    final suggestions = _weatherData!['suggestions'] ?? {};
    final rainProb = suggestions['rainProbability'] ?? 0;
    final num rainfallNum =
        (_weatherData!['rainfall'] ?? suggestions['estimatedRainfall'] ?? 0);
    final double rainfall = rainfallNum.toDouble();
    final rainDataSource =
        _weatherData!['rainDataSource'] ?? 'Dữ liệu thời tiết hiện tại';

    final String formattedTime = _lastWeatherFetchTime != null
        ? "${_lastWeatherFetchTime!.hour.toString().padLeft(2, '0')}:${_lastWeatherFetchTime!.minute.toString().padLeft(2, '0')}"
        : "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
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
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3B82F6).withOpacity(0.06),
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
                  color: const Color(0xFF3B82F6).withOpacity(0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: City Name & Refresh Time Tag Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 15,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cityName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _fetchWeatherAndQuote(force: true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formattedTime,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.refresh_rounded,
                                size: 12,
                                color: Color(0xFF2563EB),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),

                  // Main Temperature & Weather Image Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$temp°',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -1.5,
                                  height: 1.0,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 4.0, left: 2.0),
                                child: Text(
                                  'C',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Image.network(
                        iconUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.wb_sunny_rounded,
                          color: Color(0xFFF59E0B),
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 3 Stat Badges
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatBadge(
                          icon: Icons.water_drop_rounded,
                          label: 'Tỉ lệ mưa',
                          value: '$rainProb%',
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBadge(
                          icon: Icons.water_rounded,
                          label: 'Độ ẩm',
                          value: '$humidity%',
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatBadge(
                          icon: Icons.umbrella_rounded,
                          label: 'Mưa dự kiến',
                          value: '${rainfall.toStringAsFixed(1)}mm',
                          color: const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  // Action Footer: "Xem dự báo giờ & 5 ngày"
                  InkWell(
                    onTap: () => _showDetailedWeatherSheet(context, cityName),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 14,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              rainDataSource + ' · Dự báo giờ & 5 ngày',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 15,
                            color: Color(0xFF2563EB),
                          ),
                        ],
                      ),
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

  void _showDetailedWeatherSheet(BuildContext context, String city) {
    final latitude = (_weatherData?['latitude'] as num?)?.toDouble();
    final longitude = (_weatherData?['longitude'] as num?)?.toDouble();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DetailedWeatherModal(
          cityName: city,
          latitude: latitude,
          longitude: longitude,
        );
      },
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
                SearchHeaderWidget(onSearchTap: widget.onExplorePlacesTap),
                const SizedBox(height: 12),

                // Weather Widget
                _buildWeatherWidget(),
                const SizedBox(height: 14),

                // Featured Places Section
                FeaturedPlacesSection(
                  onSeeMore: widget.onExplorePlacesTap != null
                      ? () => widget.onExplorePlacesTap!('')
                      : null,
                ),
                const SizedBox(height: 14),

                // 3. Featured Guides
                FeaturedGuidesSection(onSeeMore: widget.onExploreGuidesTap),

                // Bottom padding for floating nav
                const SizedBox(height: 86),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/logo-cloudmood-new.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
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
/// Welcome text and search bar section
class SearchHeaderWidget extends StatefulWidget {
  final Function(String query)? onSearchTap;

  const SearchHeaderWidget({super.key, this.onSearchTap});

  @override
  State<SearchHeaderWidget> createState() => _SearchHeaderWidgetState();
}

class _SearchHeaderWidgetState extends State<SearchHeaderWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Interactive Search box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    widget.onSearchTap?.call(_searchController.text.trim());
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    onSubmitted: (val) {
                      widget.onSearchTap?.call(val.trim());
                    },
                    decoration: InputDecoration(
                      hintText: 'Tìm điểm đến, cẩm nang du lịch...',
                      hintStyle: TextStyle(
                        color: AppTheme.hintText,
                        fontSize: 14,
                      ),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
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
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.clear_rounded,
                        color: Colors.grey.shade400,
                        size: 18,
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: () {
                    widget.onSearchTap?.call(_searchController.text.trim());
                  },
                  child: Container(
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
  final VoidCallback? onSeeMore;
  const FeaturedGuidesSection({super.key, this.onSeeMore});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService().fetchExplorePosts(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> posts = List.from(snapshot.data ?? []);

        // Sắp xếp bài đăng dựa vào lượt xem và thả tim (Score = Likes * 10 + Views)
        posts.sort((a, b) {
          final int likesA = (a['likes'] is List)
              ? (a['likes'] as List).length
              : (int.tryParse(a['likes']?.toString() ?? '0') ?? 0);
          final int likesB = (b['likes'] is List)
              ? (b['likes'] as List).length
              : (int.tryParse(b['likes']?.toString() ?? '0') ?? 0);
          final int viewsA =
              int.tryParse(
                a['views']?.toString() ?? a['viewCount']?.toString() ?? '0',
              ) ??
              0;
          final int viewsB =
              int.tryParse(
                b['views']?.toString() ?? b['viewCount']?.toString() ?? '0',
              ) ??
              0;
          final int scoreA = likesA * 10 + viewsA;
          final int scoreB = likesB * 10 + viewsB;
          return scoreB.compareTo(scoreA);
        });

        if (snapshot.connectionState == ConnectionState.waiting &&
            posts.isEmpty) {
          return const SizedBox(
            height: 118,
            child: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (posts.isEmpty) {
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
                  Text('Hướng dẫn nổi bật', style: AppTheme.sectionTitleStyle),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllExploreGuidesScreen(),
                        ),
                      );
                    },
                    child: Container(
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 118,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final String title = (post['title'] ?? 'Cẩm nang du lịch')
                      .toString();
                  final String image =
                      (post['coverImage'] ??
                              post['image'] ??
                              post['imageUrl'] ??
                              '')
                          .toString()
                          .isNotEmpty
                      ? (post['coverImage'] ??
                                post['image'] ??
                                post['imageUrl'])
                            .toString()
                      : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&auto=format&fit=crop&q=80';
                  final String authorName =
                      (post['author']?['fullName'] ?? 'Cloudmood Guide')
                          .toString();
                  final String? avatar = post['author']?['avatar']?.toString();
                  final bool hasCustomAvatar =
                      avatar != null &&
                      avatar.trim().isNotEmpty &&
                      !avatar.toLowerCase().contains('default-avatar');
                  final String authorInitial = authorName.trim().isNotEmpty
                      ? authorName.trim()[0].toUpperCase()
                      : 'C';
                  final int likesCount = (post['likes'] is List)
                      ? (post['likes'] as List).length
                      : 0;
                  final int viewsCount =
                      int.tryParse(
                        post['views']?.toString() ??
                            post['viewCount']?.toString() ??
                            '0',
                      ) ??
                      0;
                  final String category =
                      (post['destination'] ??
                              post['categoryName'] ??
                              'Cẩm nang')
                          .toString();

                  return GestureDetector(
                    onTap: () {
                      final int? postId = (post['id'] is int)
                          ? post['id']
                          : int.tryParse(post['id'].toString());
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExplorePostDetailScreen(
                            postId: postId,
                            title: title,
                            post: post,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 180,
                      margin: const EdgeInsets.only(right: 10.0),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
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
                                  top: Radius.circular(16),
                                ),
                                child: Image.network(
                                  image,
                                  height: 64,
                                  width: 180,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 64,
                                      color: AppTheme.surfaceVariant,
                                      child: Icon(
                                        Icons.image_rounded,
                                        color: AppTheme.hintText,
                                        size: 24,
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
                                height: 35,
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
                              // Category badge
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    category,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              // Likes badge
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(130),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.favorite_rounded,
                                        color: Colors.redAccent,
                                        size: 10,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$likesCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8.5,
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
                            padding: const EdgeInsets.all(6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkText,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryContainer,
                                        shape: BoxShape.circle,
                                      ),
                                      child: hasCustomAvatar
                                          ? AvatarImage(
                                              avatarUrl: avatar,
                                              size: 18,
                                            )
                                          : Text(
                                              authorInitial,
                                              style: const TextStyle(
                                                color: AppTheme.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                height: 1,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        '$authorName · $viewsCount xem',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9.5,
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
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          title: const Text(
                            'Chuyến đi gợi ý',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.darkText,
                          elevation: 0.5,
                        ),
                        body: const CloudmoodPlacesScreen(),
                      ),
                    ),
                  );
                },
                child: Container(
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
                                title: 'Lịch trình tự thiết kế',
                                subtitle:
                                    'Chủ động chọn từng địa điểm, mốc thời gian và tùy chỉnh hành trình theo ý thích.',
                                actionText: 'Tạo thủ công →',
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
                                  colors: [
                                    Color(0xFF8E2DE2),
                                    Color(0xFF4A00E0),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                title: 'Lên lịch trình bằng AI',
                                subtitle:
                                    'Trợ lý AI tự động gợi ý địa điểm, phân bổ thời gian và tối ưu hành trình chỉ trong 5s.',
                                actionText: 'Tạo với AI →',
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
                                  colors: [
                                    Color(0xFF92400E),
                                    Color(0xFFD97706),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                title: 'Chia sẻ cẩm nang du lịch',
                                subtitle:
                                    'Viết bài chia sẻ kinh nghiệm chuyến đi, mẹo hay và địa điểm ẩn mình cho cộng đồng.',
                                actionText: 'Viết bài ngay →',
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
  final VoidCallback? onSeeMore;
  const FeaturedPlacesSection({super.key, this.onSeeMore});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService().fetchPlaces(categoryName: 'Nổi bật', limit: 8),
      builder: (context, snapshot) {
        final List<Map<String, dynamic>> places = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting &&
            places.isEmpty) {
          return const SizedBox(
            height: 118,
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
                  Text('Địa điểm nổi bật', style: AppTheme.sectionTitleStyle),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (onSeeMore != null) {
                        onSeeMore!();
                      }
                    },
                    child: Container(
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 118,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: places.length,
                itemBuilder: (context, index) {
                  final place = places[index];
                  final name = place['name'] ?? 'Địa điểm';
                  final image =
                      place['image'] != null && place['image'].isNotEmpty
                      ? place['image']
                      : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&auto=format&fit=crop&q=80';
                  final category = place['category']?['name'] ?? 'Địa điểm';
                  final rating = place['rating'] ?? 4.5;
                  final address = place['address'] ?? '';
                  return GestureDetector(
                    onTap: () {
                      PlaceDetailBottomSheet.show(context, place);
                    },
                    child: Container(
                      width: 170,
                      margin: const EdgeInsets.only(right: 10.0, bottom: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
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
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                child: Image.network(
                                  image,
                                  height: 64,
                                  width: 170,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 64,
                                    width: 170,
                                    color: AppTheme.surfaceVariant,
                                    child: Icon(
                                      Icons.image_not_supported_rounded,
                                      color: AppTheme.subtitleText,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    category,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(130),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 10,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        rating is num
                                            ? rating.toStringAsFixed(1)
                                            : '4.5',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8.5,
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
                            padding: const EdgeInsets.all(6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkText,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: 11,
                                      color: AppTheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9.5,
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

class _DetailedWeatherModal extends StatefulWidget {
  final String cityName;
  final double? latitude;
  final double? longitude;
  const _DetailedWeatherModal({
    required this.cityName,
    this.latitude,
    this.longitude,
  });

  @override
  State<_DetailedWeatherModal> createState() => _DetailedWeatherModalState();
}

class _DetailedWeatherModalState extends State<_DetailedWeatherModal> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _forecastData;
  int _selectedHourlyIndex = 0;
  int? _expandedDayIndex;

  List<Map<String, dynamic>> get _hourlyForecasts {
    final items = _forecastData?['hourly'];
    if (items is! List) return <Map<String, dynamic>>[];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> get _dailyForecasts {
    final items = _forecastData?['daily'];
    if (items is! List) return <Map<String, dynamic>>[];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchForecast();
  }

  Future<void> _fetchForecast() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.get(
        '/weather/forecast',
        query: {
          'cityName': widget.cityName,
          if (widget.latitude != null) 'lat': widget.latitude.toString(),
          if (widget.longitude != null) 'lon': widget.longitude.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _forecastData = data;
            _selectedHourlyIndex = 0;
            _expandedDayIndex = null;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Không thể tải dự báo thời tiết';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi kết nối mạng';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Drag handle line
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.wb_sunny_rounded,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.cityName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Dự báo thời tiết 5 ngày',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Body Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchForecast,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current overview banner inside modal
                        _buildCurrentBanner(_forecastData!['current']),
                        const SizedBox(height: 24),

                        // SECTION 1: Hourly Forecast (Dự báo theo giờ)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'DỰ BÁO THEO GIỜ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Chạm xem · 3 giờ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 130,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _hourlyForecasts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final item = _hourlyForecasts[index];
                              return _buildHourlyCard(
                                item,
                                index == _selectedHourlyIndex,
                                () {
                                  setState(() {
                                    _selectedHourlyIndex = index;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        if (_hourlyForecasts.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _buildHourlyDetails(
                            _hourlyForecasts[_selectedHourlyIndex.clamp(
                              0,
                              _hourlyForecasts.length - 1,
                            )],
                          ),
                        ],
                        const SizedBox(height: 28),

                        // SECTION 2: 5-Day Forecast (Dự báo 5 ngày)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'DỰ BÁO 5 NGÀY TỚI',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Chạm để mở',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            for (
                              var index = 0;
                              index < _dailyForecasts.length;
                              index++
                            )
                              _buildDailyRow(
                                _dailyForecasts[index],
                                index == _expandedDayIndex,
                                () {
                                  setState(() {
                                    _expandedDayIndex =
                                        _expandedDayIndex == index
                                        ? null
                                        : index;
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBanner(Map<String, dynamic>? current) {
    if (current == null) return const SizedBox.shrink();
    final temp = current['temp'] ?? 25;
    final desc = current['description'] ?? '';
    final iconCode = current['icon'] ?? '01d';
    final iconUrl = 'https://openweathermap.org/img/wn/$iconCode@2x.png';
    final pop = current['pop'] ?? 0;
    final humidity = current['humidity'] ?? 0;
    final feelsLike = current['feelsLike'];
    final windSpeed = current['windSpeed'];
    final rainAmount = current['rainAmount'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$temp°C',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  desc.toString().toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildWhiteChip(Icons.umbrella_rounded, 'Mưa: $pop%'),
                    _buildWhiteChip(Icons.water_drop_rounded, 'Ẩm: $humidity%'),
                    if (feelsLike != null)
                      _buildWhiteChip(
                        Icons.thermostat_rounded,
                        'Cảm giác: $feelsLike°',
                      ),
                    if (windSpeed != null)
                      _buildWhiteChip(
                        Icons.air_rounded,
                        'Gió: ${_formatMetricNumber(windSpeed, decimals: 1)} m/s',
                      ),
                    if (rainAmount is num && rainAmount > 0)
                      _buildWhiteChip(
                        Icons.grain_rounded,
                        'Lượng mưa: ${_formatMetricNumber(rainAmount, decimals: 1)} mm',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Image.network(
            iconUrl,
            width: 72,
            height: 72,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.wb_sunny_rounded,
              size: 60,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMetricNumber(dynamic value, {int decimals = 0}) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (number == null || !number.isFinite) return '--';
    return decimals == 0
        ? number.round().toString()
        : number.toStringAsFixed(decimals);
  }

  Widget _buildHourlyCard(
    Map<String, dynamic> item,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final time = item['time'] ?? '00:00';
    final temp = item['temp'] ?? 0;
    final iconCode = item['icon'] ?? '01d';
    final pop = item['pop'] ?? 0;
    final iconUrl = 'https://openweathermap.org/img/wn/$iconCode@2x.png';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFF1E40AF)
                    : const Color(0xFF64748B),
              ),
            ),
            Image.network(
              iconUrl,
              width: 38,
              height: 38,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.cloud, size: 28, color: Colors.blue),
            ),
            Text(
              '$temp°',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            if (pop > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.water_drop,
                    size: 10,
                    color: Color(0xFF0284C7),
                  ),
                  Text(
                    '$pop%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              )
            else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyDetails(Map<String, dynamic> item) {
    final time = item['time'] ?? '--:--';
    final date = item['dateStr']?.toString() ?? '';
    final description = item['description']?.toString() ?? '';
    final metrics = <Widget>[
      if (item['feelsLike'] != null)
        _buildDetailMetric(
          Icons.thermostat_rounded,
          'Cảm giác như',
          '${_formatMetricNumber(item['feelsLike'])}°C',
        ),
      if (item['pop'] != null)
        _buildDetailMetric(
          Icons.umbrella_rounded,
          'Xác suất mưa',
          '${_formatMetricNumber(item['pop'])}%',
        ),
      if (item['rainAmount'] != null)
        _buildDetailMetric(
          Icons.grain_rounded,
          'Lượng mưa/3 giờ',
          '${_formatMetricNumber(item['rainAmount'], decimals: 1)} mm',
        ),
      if (item['humidity'] != null)
        _buildDetailMetric(
          Icons.water_drop_rounded,
          'Độ ẩm',
          '${_formatMetricNumber(item['humidity'])}%',
        ),
      if (item['windSpeed'] != null)
        _buildDetailMetric(
          Icons.air_rounded,
          'Tốc độ gió',
          '${_formatMetricNumber(item['windSpeed'], decimals: 1)} m/s',
        ),
      if (item['windGust'] is num && (item['windGust'] as num) > 0)
        _buildDetailMetric(
          Icons.storm_rounded,
          'Gió giật',
          '${_formatMetricNumber(item['windGust'], decimals: 1)} m/s',
        ),
      if (item['pressure'] != null)
        _buildDetailMetric(
          Icons.speed_rounded,
          'Áp suất',
          '${_formatMetricNumber(item['pressure'])} hPa',
        ),
      if (item['visibilityKm'] != null)
        _buildDetailMetric(
          Icons.visibility_rounded,
          'Tầm nhìn',
          '${_formatMetricNumber(item['visibilityKm'], decimals: 1)} km',
        ),
      if (item['cloudiness'] != null)
        _buildDetailMetric(
          Icons.cloud_rounded,
          'Độ phủ mây',
          '${_formatMetricNumber(item['cloudiness'])}%',
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 6),
              Text(
                'Chi tiết $time${date.isEmpty ? '' : ' · $date'}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              description,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildMetricGrid(metrics),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricGrid(List<Widget> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in metrics)
              SizedBox(width: itemWidth, child: metric),
          ],
        );
      },
    );
  }

  Widget _buildDetailMetric(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRow(
    Map<String, dynamic> item,
    bool isExpanded,
    VoidCallback onTap,
  ) {
    final dayName = item['dayName'] ?? '';
    final minTemp = item['minTemp'] ?? 0;
    final maxTemp = item['maxTemp'] ?? 0;
    final desc = item['description'] ?? '';
    final iconCode = item['icon'] ?? '01d';
    final pop = item['popMax'] ?? 0;
    final iconUrl = 'https://openweathermap.org/img/wn/$iconCode@2x.png';

    final metrics = <Widget>[
      _buildDetailMetric(
        Icons.thermostat_rounded,
        'Nhiệt độ',
        '${_formatMetricNumber(minTemp)}° – ${_formatMetricNumber(maxTemp)}°',
      ),
      if (item['feelsLikeMin'] != null && item['feelsLikeMax'] != null)
        _buildDetailMetric(
          Icons.device_thermostat_rounded,
          'Cảm giác như',
          '${_formatMetricNumber(item['feelsLikeMin'])}° – ${_formatMetricNumber(item['feelsLikeMax'])}°',
        ),
      _buildDetailMetric(
        Icons.umbrella_rounded,
        'Mưa cao nhất',
        '${_formatMetricNumber(pop)}%',
      ),
      if (item['rainTotal'] != null)
        _buildDetailMetric(
          Icons.grain_rounded,
          'Tổng lượng mưa',
          '${_formatMetricNumber(item['rainTotal'], decimals: 1)} mm',
        ),
      if (item['averageHumidity'] != null)
        _buildDetailMetric(
          Icons.water_drop_rounded,
          'Độ ẩm trung bình',
          '${_formatMetricNumber(item['averageHumidity'])}%',
        ),
      if (item['maxWindSpeed'] != null)
        _buildDetailMetric(
          Icons.air_rounded,
          'Gió mạnh nhất',
          '${_formatMetricNumber(item['maxWindSpeed'], decimals: 1)} m/s',
        ),
      if (item['maxWindGust'] is num && (item['maxWindGust'] as num) > 0)
        _buildDetailMetric(
          Icons.storm_rounded,
          'Gió giật',
          '${_formatMetricNumber(item['maxWindGust'], decimals: 1)} m/s',
        ),
      if (item['averagePressure'] != null)
        _buildDetailMetric(
          Icons.speed_rounded,
          'Áp suất trung bình',
          '${_formatMetricNumber(item['averagePressure'])} hPa',
        ),
      if (item['minVisibilityKm'] != null)
        _buildDetailMetric(
          Icons.visibility_rounded,
          'Tầm nhìn thấp nhất',
          '${_formatMetricNumber(item['minVisibilityKm'], decimals: 1)} km',
        ),
      if (item['maxCloudiness'] != null)
        _buildDetailMetric(
          Icons.cloud_rounded,
          'Mây nhiều nhất',
          '${_formatMetricNumber(item['maxCloudiness'])}%',
        ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isExpanded ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? const Color(0xFFBFDBFE) : const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(
                      dayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Image.network(
                    iconUrl,
                    width: 34,
                    height: 34,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.wb_sunny,
                      size: 24,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: pop > 0
                        ? Text(
                            'Mưa: $pop%',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          )
                        : Text(
                            desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                  ),
                  Text(
                    '${_formatMetricNumber(minTemp)}°',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 34,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFFF97316)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_formatMetricNumber(maxTemp)}°',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFDBEAFE)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (desc.toString().isNotEmpty) ...[
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildMetricGrid(metrics),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
