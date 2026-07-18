import 'dart:convert';
import 'package:flutter/material.dart';
import 'guide_overview_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user.dart';
import '../widgets/avatar_image.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'create_itinerary_wizard_sheet.dart';
import 'trip_overview_screen.dart';

Future<XFile?> _selectImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Thay đổi ảnh đại diện',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppTheme.primary,
                  ),
                ),
                title: const Text(
                  'Chụp ảnh mới',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              const Divider(color: AppTheme.border, height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.lightAmber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: AppTheme.amber,
                  ),
                ),
                title: const Text(
                  'Chọn từ thư viện',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );

  if (source != null) {
    try {
      return await ImagePicker().pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 70,
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }
  return null;
}

class CloudmoodProfileScreen extends StatefulWidget {
  const CloudmoodProfileScreen({super.key});

  @override
  State<CloudmoodProfileScreen> createState() => _CloudmoodProfileScreenState();
}

class _CloudmoodProfileScreenState extends State<CloudmoodProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  bool _notifEnabled = true;
  bool _darkModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEditProfileSheet(
    BuildContext context,
    String currentName,
    String currentAvatar,
  ) {
    final nameController = TextEditingController(text: currentName);
    String selectedAvatar = currentAvatar;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chỉnh sửa hồ sơ',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkText,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppTheme.subtitleText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: AppTheme.inputDecoration(
                        hintText: 'Họ và tên',
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Ảnh đại diện',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final pickedFile = await _selectImage(context);
                          if (pickedFile != null) {
                            final bytes = await pickedFile.readAsBytes();
                            final base64String =
                                'data:image/jpeg;base64,${base64Encode(bytes)}';
                            setModalState(() {
                              selectedAvatar = base64String;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                          ),
                          child: ClipOval(
                            child: Container(
                              width: 100,
                              height: 100,
                              color: AppTheme.surfaceVariant,
                              child: AvatarImage(
                                avatarUrl: selectedAvatar,
                                size: 100,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Nhấn vào ảnh để đổi ảnh đại diện từ thiết bị',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtitleText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () async {
                        final updated = await _authService.updateProfile(
                          fullName: nameController.text.trim(),
                          avatarUrl: selectedAvatar,
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          if (updated) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Hồ sơ đã được cập nhật!'),
                                backgroundColor: AppTheme.green,
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        height: 52,
                        width: double.infinity,
                        decoration: AppTheme.gradientButtonDecoration(),
                        child: const Center(
                          child: Text(
                            'Lưu thay đổi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmNewPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Đổi mật khẩu',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Mật khẩu hiện tại',
                      prefixIcon: Icons.lock_open_rounded,
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Nhập mật khẩu hiện tại.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Mật khẩu mới',
                      prefixIcon: Icons.lock_outline_rounded,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Nhập mật khẩu mới.';
                      if (v.length < 8)
                        return 'Mật khẩu phải có ít nhất 8 ký tự.';
                      if (!v.contains(RegExp(r'[A-Z]'))) {
                        return 'Mật khẩu phải có ít nhất 1 chữ viết hoa.';
                      }
                      if (!v.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
                        return 'Mật khẩu phải có ít nhất 1 ký tự đặc biệt.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmNewPasswordController,
                    obscureText: true,
                    decoration: AppTheme.inputDecoration(
                      hintText: 'Xác nhận mật khẩu mới',
                      prefixIcon: Icons.lock_rounded,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Xác nhận mật khẩu.';
                      if (v != newPasswordController.text) {
                        return 'Mật khẩu không khớp.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppTheme.subtitleText, fontFamily: 'SDK_SC_Web-Heavy', fontWeight: FontWeight.bold),
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
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final result = await _authService.changePassword(
                  currentPassword: currentPasswordController.text,
                  newPassword: newPasswordController.text,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] as String),
                      backgroundColor: (result['success'] as bool)
                          ? AppTheme.green
                          : AppTheme.red,
                    ),
                  );
                }
              },
              child: const Text('Đổi mật khẩu', style: TextStyle(fontFamily: 'SDK_SC_Web-Heavy', fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppTheme.red, size: 22),
              SizedBox(width: 10),
              Text(
                'Đăng xuất',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản Cloudmood?',
            style: TextStyle(color: AppTheme.bodyText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppTheme.subtitleText, fontFamily: 'SDK_SC_Web-Heavy', fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                _authService.logout();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã đăng xuất thành công!'),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              },
              child: const Text('Đăng xuất', style: TextStyle(fontFamily: 'SDK_SC_Web-Heavy', fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _authService.currentUser,
      builder: (context, user, child) {
        if (user == null) {
          return _buildGuestScreen(context);
        }
        return ProfileDashboard(
          user: user,
          notifEnabled: _notifEnabled,
          darkModeEnabled: _darkModeEnabled,
          onNotifChanged: (v) => setState(() => _notifEnabled = v),
          onDarkModeChanged: (v) => setState(() => _darkModeEnabled = v),
          onEditProfile: _showEditProfileSheet,
          onChangePassword: _showChangePasswordDialog,
          onLogout: _showLogoutConfirmDialog,
        );
      },
    );
  }

  // Guest welcome screen
  Widget _buildGuestScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Top gradient blob
          Container(
            height: 280,
            decoration: const BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -50,
                  right: -60,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(15),
                    ),
                  ),
                ),
                const SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 64,
                          color: Colors.white54,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chưa đăng nhập',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 250),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Lưu giữ và chia sẻ hành trình du lịch của bạn. Khám phá các điểm đến được gợi ý dựa trên tâm trạng.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.subtitleText,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CloudmoodLoginScreen(),
                              ),
                            );
                          },
                          child: Container(
                            height: 52,
                            width: double.infinity,
                            decoration: AppTheme.gradientButtonDecoration(),
                            child: const Center(
                              child: Text(
                                'Đăng nhập tài khoản',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Chưa có tài khoản? ',
                              style: TextStyle(color: AppTheme.subtitleText),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CloudmoodRegisterScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Đăng ký ngay',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}

// ─── Logged-in Profile Dashboard ────────────────────────────────────────────────
class ProfileDashboard extends StatefulWidget {
  final UserModel user;
  final bool notifEnabled;
  final bool darkModeEnabled;
  final ValueChanged<bool> onNotifChanged;
  final ValueChanged<bool> onDarkModeChanged;
  final Function(BuildContext, String, String) onEditProfile;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  const ProfileDashboard({
    super.key,
    required this.user,
    required this.notifEnabled,
    required this.darkModeEnabled,
    required this.onNotifChanged,
    required this.onDarkModeChanged,
    required this.onEditProfile,
    required this.onChangePassword,
    required this.onLogout,
  });

  @override
  State<ProfileDashboard> createState() => _ProfileDashboardState();
}

class _ProfileDashboardState extends State<ProfileDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _itineraries = [];
  List<Map<String, dynamic>> _guides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    DatabaseService.refreshTrigger.addListener(_loadData);
  }

  @override
  void dispose() {
    DatabaseService.refreshTrigger.removeListener(_loadData);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final itineraries = await DatabaseService().fetchUserItineraries(
      widget.user.id,
      isGuide: false,
    );

    final guides = await DatabaseService().fetchUserItineraries(
      widget.user.id,
      isGuide: true,
    );

    if (!mounted) return;
    setState(() {
      _itineraries = itineraries;
      _guides = guides;
      _isLoading = false;
    });
  }

  final AuthService _authService = AuthService();

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    try {
      final pickedFile = await _selectImage(context);
      if (pickedFile != null) {
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        );

        final bytes = await pickedFile.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

        final updated = await _authService.updateProfile(
          fullName: widget.user.fullName,
          avatarUrl: base64String,
        );

        if (context.mounted) {
          Navigator.of(context).pop(); // dismiss loading
          if (updated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ảnh đại diện đã được cập nhật!'),
                backgroundColor: AppTheme.green,
              ),
            );
            _loadData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cập nhật ảnh đại diện thất bại.'),
                backgroundColor: AppTheme.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  String _formatBudget(int budget) {
    if (budget >= 1000000) {
      double m = budget / 1000000.0;
      return '${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)}Tr';
    } else if (budget >= 1000) {
      double k = budget / 1000.0;
      return '${k.toStringAsFixed(k % 1 == 0 ? 0 : 1)}k';
    }
    return '$budget';
  }

  void _showCreateItinerarySheet(BuildContext context) {
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CreateItineraryWizardSheet(userId: widget.user.id);
      },
    ).then((result) {
      if (result != null && context.mounted) {
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
    final String joinDate =
        '${widget.user.createdAt.day}/${widget.user.createdAt.month}/${widget.user.createdAt.year}';
    final String roleText = widget.user.role
        ? 'Quản trị viên'
        : 'Thành viên PRO';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // ── Hero SliverAppBar ──────────────────────────────────
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              backgroundColor: AppTheme.primaryDark,
              elevation: 0,
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  onPressed: () => widget.onEditProfile(
                    context,
                    widget.user.fullName,
                    widget.user.avatar ?? '',
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  onPressed: widget.onLogout,
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.heroGradient,
                  ),
                  child: Stack(
                    children: [
                      // Decorative circle
                      Positioned(
                        top: -60,
                        right: -60,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(12),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -30,
                        left: -40,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(8),
                          ),
                        ),
                      ),
                      // Content
                      SafeArea(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              // Avatar with gradient ring
                              GestureDetector(
                                onTap: () => _pickAndUploadAvatar(context),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Colors.white70, Colors.white30],
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Container(
                                      width: 88,
                                      height: 88,
                                      color: AppTheme.surfaceVariant,
                                      child: AvatarImage(
                                        avatarUrl: widget.user.avatar,
                                        size: 88,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.user.fullName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(20),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(40),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: Colors.white70,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      roleText,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Tab bar ────────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.subtitleText,
                  indicatorColor: AppTheme.primary,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'Lịch trình'),
                    Tab(text: 'Hướng dẫn'),
                    Tab(text: 'Cài đặt'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // ── Tab 1: Itineraries ────────────────────────────────
            _buildItineraryTab(),
            // ── Tab 2: Guides ────────────────────────────────────
            _buildGuidesTab(),
            // ── Tab 3: Settings ───────────────────────────────────
            _buildSettingsTab(joinDate),
          ],
        ),
      ),
    );
  }

  Widget _buildItineraryTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primary,
          strokeWidth: 2.5,
        ),
      );
    }

    if (_itineraries.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.map_outlined,
                  size: 48,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chưa có hành trình nào',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hãy tạo hành trình đầu tiên của bạn!',
                style: TextStyle(color: AppTheme.subtitleText, fontSize: 13),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _showCreateItinerarySheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: AppTheme.gradientButtonDecoration(radius: 14),
                  child: const Text(
                    '+ Tạo hành trình',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: _itineraries.length,
      itemBuilder: (context, index) {
        final trip = _itineraries[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TripOverviewScreen(itinerary: trip),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.premiumCardDecoration(),
            child: Row(
              children: [
                // Image thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: trip['image_url'] != null
                        ? Image.network(
                            trip['image_url'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.flight_takeoff_rounded,
                              color: Colors.white70,
                              size: 28,
                            ),
                          )
                        : const Icon(
                            Icons.flight_takeoff_rounded,
                            color: Colors.white70,
                            size: 28,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip['title'] as String? ?? 'Hành trình',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: AppTheme.subtitleText,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              trip['destination'] as String? ?? 'Chưa xác định',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.subtitleText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildTripChip(
                            '${trip['days'] ?? '?'} ngày',
                            Icons.calendar_today_rounded,
                            AppTheme.primaryContainer,
                            AppTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          if (trip['budget'] != null)
                            _buildTripChip(
                              _formatBudget(
                                (trip['budget'] is num)
                                    ? (trip['budget'] as num).toInt()
                                    : int.tryParse(trip['budget'].toString()) ??
                                          0,
                              ),
                              Icons.payments_rounded,
                              AppTheme.lightGreen,
                              AppTheme.green,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.subtitleText,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTripChip(String label, IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidesTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_guides.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.lightAmber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 48,
                  color: AppTheme.amber,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chưa có hướng dẫn nào',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hãy tạo hướng dẫn chuyến đi của riêng bạn!',
                style: TextStyle(color: AppTheme.subtitleText, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: _guides.length,
      itemBuilder: (context, index) {
        final guide = _guides[index];
        final sections = (guide['sections'] as List?)?.length ?? 0;
        final savedPlaces = (guide['savedPlaces'] as List?)?.length ?? 0;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GuideOverviewScreen(itinerary: guide),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.premiumCardDecoration(),
            child: Row(
              children: [
                // Icon thumbnail
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [AppTheme.amber.withAlpha(200), AppTheme.amber],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guide['title'] as String? ?? 'Hướng dẫn',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: AppTheme.subtitleText,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              guide['destination'] as String? ??
                                  'Chưa xác định',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.subtitleText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildTripChip(
                            '$savedPlaces địa điểm',
                            Icons.place_rounded,
                            AppTheme.lightAmber,
                            AppTheme.amber,
                          ),
                          const SizedBox(width: 6),
                          _buildTripChip(
                            '$sections mục',
                            Icons.list_alt_rounded,
                            AppTheme.primaryContainer,
                            AppTheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.subtitleText,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab(String joinDate) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        // Account info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.premiumCardDecoration(),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.email_outlined,
                'Email',
                widget.user.email,
                AppTheme.primary,
              ),
              const Divider(color: AppTheme.divider),
              _buildInfoRow(
                Icons.calendar_today_rounded,
                'Ngày tham gia',
                joinDate,
                AppTheme.green,
              ),
              const Divider(color: AppTheme.divider),
              _buildInfoRow(
                Icons.verified_rounded,
                'Vai trò',
                widget.user.role ? 'Quản trị viên' : 'Thành viên PRO',
                AppTheme.amber,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Preferences
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.premiumCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tùy chọn',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.subtitleText,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildToggleTile(
                icon: Icons.notifications_active_rounded,
                iconBg: AppTheme.primaryContainer,
                iconColor: AppTheme.primary,
                title: 'Thông báo',
                subtitle: 'Nhận cập nhật về hành trình',
                value: widget.notifEnabled,
                onChanged: widget.onNotifChanged,
              ),
              const Divider(color: AppTheme.divider),
              _buildToggleTile(
                icon: Icons.dark_mode_rounded,
                iconBg: const Color(0xFF2D2D3A).withAlpha(20),
                iconColor: const Color(0xFF6366F1),
                title: 'Chế độ tối',
                subtitle: 'Giao diện tối hơn',
                value: widget.darkModeEnabled,
                onChanged: widget.onDarkModeChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.premiumCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tài khoản',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.subtitleText,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              _buildActionTile(
                icon: Icons.lock_outline_rounded,
                iconBg: AppTheme.accentLight,
                iconColor: AppTheme.accent,
                title: 'Đổi mật khẩu',
                onTap: widget.onChangePassword,
              ),
              const Divider(color: AppTheme.divider),
              _buildActionTile(
                icon: Icons.help_outline_rounded,
                iconBg: AppTheme.lightAmber,
                iconColor: AppTheme.amber,
                title: 'Trợ giúp & Hỗ trợ',
                onTap: () {},
              ),
              const Divider(color: AppTheme.divider),
              _buildActionTile(
                icon: Icons.logout_rounded,
                iconBg: AppTheme.lightRed,
                iconColor: AppTheme.red,
                title: 'Đăng xuất',
                titleColor: AppTheme.red,
                onTap: widget.onLogout,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // App version
        const Center(
          child: Text(
            'cloudmood v1.0.0 — Phiên bản hiện tại',
            style: TextStyle(fontSize: 11, color: AppTheme.hintText),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.subtitleText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.subtitleText,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
            activeTrackColor: AppTheme.primaryContainer,
            inactiveThumbColor: AppTheme.subtitleText,
            inactiveTrackColor: AppTheme.surfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: titleColor ?? AppTheme.darkText,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.subtitleText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sticky Tab Bar Delegate ─────────────────────────────────────────────────
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _StickyTabBarDelegate(this.tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppTheme.background, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
