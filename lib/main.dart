import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/places_screen.dart';
import 'screens/deals_screen.dart';
import 'screens/forum_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/create_itinerary_wizard_sheet.dart';
import 'screens/create_guide_wizard_sheet.dart';
import 'screens/trip_overview_screen.dart';
import 'screens/trip_ai_chat_screen.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load user's theme preference
  await AppTheme.loadTheme();

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Seed initial categories & places in Supabase if empty
  await DatabaseService().checkAndSeedData();

  if (kIsWeb) {
    await FacebookAuth.instance.webAndDesktopInitialize(
      appId: '3145996625791025',
      cookie: true,
      xfbml: true,
      version: 'v19.0',
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'CLOUDMOOD',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const CloudmoodMainShell(),
        );
      },
    );
  }
}

class CloudmoodMainShell extends StatefulWidget {
  const CloudmoodMainShell({super.key});

  @override
  State<CloudmoodMainShell> createState() => _CloudmoodMainShellState();
}

class _CloudmoodMainShellState extends State<CloudmoodMainShell> {
  int _currentIndex = 0;

  // Render current body based on bottom navigation index
  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return CloudmoodHomeScreen(
          onProfileTap: () {
            setState(() {
              _currentIndex = 4; // Switch to profile tab
            });
          },
        );
      case 1:
        return const CloudmoodPlacesScreen();
      case 3:
        return const CloudmoodForumScreen();
      case 4:
        return const CloudmoodProfileScreen();
      default:
        return CloudmoodHomeScreen(
          onProfileTap: () {
            setState(() {
              _currentIndex = 4;
            });
          },
        );
    }
  }

  void _handleNavTap(int index) {
    if (index == 2) {
      _showCreateMenuOverlay();
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _showCreateMenuOverlay() {
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            opaque: false,
            barrierDismissible: true,
            pageBuilder: (context, _, _) =>
                const CreateMenuOverlay(animationValue: 1.0),
            transitionsBuilder: (context, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        )
        .then((result) {
          if (result == 'create_itinerary') {
            _openCreateItinerarySheet();
          } else if (result == 'ai_chat') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TripAIChatScreen(destination: 'Đà Nẵng'),
              ),
            );
          } else if (result == 'create_guide') {
            _openCreateGuideSheet();
          }
        });
  }

  void _openCreateItinerarySheet() {
    final user = AuthService().currentUser.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng đăng nhập để tạo lịch trình!'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.fixed,
          action: SnackBarAction(
            label: 'Đăng nhập',
            textColor: Colors.white,
            onPressed: () {
              setState(() => _currentIndex = 4);
            },
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CreateItineraryWizardSheet(userId: user.id);
      },
    ).then((result) {
      if (result != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TripOverviewScreen(itinerary: result),
          ),
        );
      }
    });
  }

  void _openCreateGuideSheet() {
    final user = AuthService().currentUser.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng đăng nhập để tạo hướng dẫn!'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.fixed,
          action: SnackBarAction(
            label: 'Đăng nhập',
            textColor: Colors.white,
            onPressed: () {
              setState(() => _currentIndex = 4);
            },
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CreateGuideWizardSheet(userId: user.id);
      },
    ).then((result) {
      if (result != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TripOverviewScreen(itinerary: result),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _buildBody(),
      bottomNavigationBar: _CloudmoodFloatingNav(
        selectedIndex: _currentIndex,
        onTap: _handleNavTap,
      ),
    );
  }
}

// ─── Floating Bottom Navigation Bar ────────────────────────────────────────────
class _CloudmoodFloatingNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _CloudmoodFloatingNav({
    required this.selectedIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItem(
      icon: Icons.home_rounded,
      activeIcon: Icons.home_rounded,
      label: 'Trang chủ',
    ),
    _NavItem(
      icon: Icons.place_outlined,
      activeIcon: Icons.place_rounded,
      label: 'Địa điểm',
    ),
    _NavItem(
      icon: Icons.add_circle_outline_rounded,
      activeIcon: Icons.add_circle_rounded,
      label: 'Tạo lịch',
    ),
    _NavItem(
      icon: Icons.feed_outlined,
      activeIcon: Icons.feed_rounded,
      label: 'Diễn đàn',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Hồ sơ',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A56DB).withAlpha(30),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final isSelected = i == selectedIndex;
            return _NavButton(
              item: item,
              isSelected: isSelected,
              onTap: () => onTap(i),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withAlpha(18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? AppTheme.primary : AppTheme.subtitleText,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Legacy alias for backward compat (used in home_screen.dart)
class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _CloudmoodFloatingNav(selectedIndex: selectedIndex, onTap: onTap);
  }
}
