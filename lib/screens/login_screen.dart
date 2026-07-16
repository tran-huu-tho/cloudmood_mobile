import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class CloudmoodLoginScreen extends StatefulWidget {
  const CloudmoodLoginScreen({super.key});

  @override
  State<CloudmoodLoginScreen> createState() => _CloudmoodLoginScreenState();
}

class _CloudmoodLoginScreenState extends State<CloudmoodLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // Handle standard Login
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final response = await _authService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (response['success'] as bool) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] as String),
            backgroundColor: AppTheme.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] as String),
            backgroundColor: AppTheme.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Handle Google Sign-in
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        final response = await _authService.loginWithGoogle(
          email: googleUser.email,
          fullName: googleUser.displayName ?? 'Người dùng Google',
          avatarUrl: googleUser.photoUrl,
          token: googleAuth.idToken,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] as String),
              backgroundColor: response['success'] as bool ? AppTheme.green : AppTheme.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (response['success'] as bool) {
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      debugPrint('Google Native Sign-In failed: $e. Falling back to simulator.');
      if (mounted) {
        _showSocialLoginBottomSheet(true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Handle Facebook Sign-in
  Future<void> _handleFacebookSignIn() async {
    setState(() => _isLoading = true);
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );
      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final userData = await FacebookAuth.instance.getUserData();
        
        final response = await _authService.loginWithFacebook(
          email: userData['email'] ?? 'facebook-user@example.com',
          fullName: userData['name'] ?? 'Người dùng Facebook',
          avatarUrl: userData['picture']?['data']?['url'],
          token: accessToken.token,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] as String),
              backgroundColor: response['success'] as bool ? AppTheme.green : AppTheme.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          if (response['success'] as bool) {
            Navigator.of(context).pop();
          }
        }
      } else {
        throw Exception('Facebook login status: ${result.status}');
      }
    } catch (e) {
      debugPrint('Facebook Native Sign-In failed: $e. Falling back to simulator.');
      if (mounted) {
        _showSocialLoginBottomSheet(false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Social Login Bottom Sheet Simulation
  void _showSocialLoginBottomSheet(bool isGoogle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isSheetLoading = false;
        bool isCustomInput = false;
        final sheetEmailCtrl = TextEditingController();
        final sheetNameCtrl = TextEditingController();
        final sheetFormKey = GlobalKey<FormState>();

        final defaultAccounts = isGoogle
            ? [
                {'name': 'Nguyễn Minh Triết', 'email': 'triet.minh@gmail.com', 'avatar': 'https://i.pravatar.cc/150?img=33'},
                {'name': 'Lê Hoàng Nam', 'email': 'nam.le99@gmail.com', 'avatar': 'https://i.pravatar.cc/150?img=12'},
                {'name': 'Phạm Thanh Thảo', 'email': 'thao.pham@gmail.com', 'avatar': 'https://i.pravatar.cc/150?img=47'},
              ]
            : [
                {'name': 'Trần Quốc Huy', 'email': 'huy.tran.fb@gmail.com', 'avatar': 'https://i.pravatar.cc/150?img=60'},
                {'name': 'Nguyễn Hải Đường', 'email': 'duong.hai@gmail.com', 'avatar': 'https://i.pravatar.cc/150?img=59'},
              ];

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> executeSocialLogin(String email, String name, String avatar) async {
              setModalState(() => isSheetLoading = true);
              
              final response = isGoogle 
                  ? await _authService.loginWithGoogle(email: email, fullName: name, avatarUrl: avatar)
                  : await _authService.loginWithFacebook(email: email, fullName: name, avatarUrl: avatar);

              setModalState(() => isSheetLoading = false);

              if (mounted) {
                Navigator.of(context).pop(); // Close bottom sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(response['message'] as String),
                    backgroundColor: response['success'] as bool ? AppTheme.green : AppTheme.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                if (response['success'] as bool) {
                  Navigator.of(this.context).pop(); // Close login screen
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          isGoogle
                              ? Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                                  height: 24,
                                )
                              : const Icon(
                                  Icons.facebook,
                                  color: Color(0xFF1877F2),
                                  size: 26,
                                ),
                          const SizedBox(width: 12),
                          Text(
                            isGoogle ? 'Đăng nhập với Google' : 'Đăng nhập với Facebook',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 30, thickness: 1),
                      if (isSheetLoading) ...[
                        const SizedBox(height: 40),
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            isGoogle ? 'Đang xác thực tài khoản Google...' : 'Đang kết nối tài khoản Facebook...',
                            style: const TextStyle(color: AppTheme.subtitleText),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ] else if (!isCustomInput) ...[
                        const Text(
                          'Chọn tài khoản để tiếp tục',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.subtitleText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...defaultAccounts.map((acc) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: InkWell(
                              onTap: () => executeSocialLogin(acc['email']!, acc['name']!, acc['avatar']!),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: NetworkImage(acc['avatar']!),
                                      radius: 20,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            acc['name']!,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.darkText,
                                            ),
                                          ),
                                          Text(
                                            acc['email']!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.subtitleText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: Colors.grey,
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                isCustomInput = true;
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 20),
                            label: const Text(
                              'Sử dụng tài khoản khác',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Form(
                          key: sheetFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nhập thông tin tài khoản thử nghiệm:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.subtitleText,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: sheetNameCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Họ và tên',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: const Icon(Icons.person),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập họ tên.' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: sheetEmailCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: const Icon(Icons.email),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Vui lòng nhập email.';
                                  if (!val.contains('@')) return 'Email không hợp lệ.';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setModalState(() {
                                          isCustomInput = false;
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      child: const Text('Quay lại'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (sheetFormKey.currentState!.validate()) {
                                          executeSocialLogin(
                                            sheetEmailCtrl.text.trim(),
                                            sheetNameCtrl.text.trim(),
                                            'https://i.pravatar.cc/150?img=15',
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.darkText,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      child: const Text('Đăng nhập'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE0F2FE), // Light sky blue
              Color(0xFFF8FAFC), // Off-white
              Colors.white,
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button and header logo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: AppTheme.darkText,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Illustration and Logo container
                  Center(
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: size.height * 0.32,
                            ),
                            child: Image.asset(
                              'assets/images/login_illustration.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 180,
                                  width: size.width * 0.8,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.airport_shuttle_rounded,
                                      size: 80,
                                      color: AppTheme.primaryLight,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Floating Logo / Signpost
                          Positioned(
                            top: 10,
                            right: size.width * 0.15,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBBF24), // Yellow
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF1E293B), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.wb_cloudy_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Header title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đăng nhập để Khám phá\nLịch trình của bạn',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                height: 1.3,
                                color: AppTheme.darkText,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Inputs and Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: Column(
                          children: [
                            // Email field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: 'Nhập địa chỉ email',
                                hintStyle: const TextStyle(color: AppTheme.hintText, fontSize: 15),
                                prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.hintText, size: 20),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.black.withOpacity(0.06), width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppTheme.red, width: 1.5),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppTheme.red, width: 1.5),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vui lòng nhập email.';
                                }
                                final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                if (!regex.hasMatch(value.trim())) {
                                  return 'Định dạng email không hợp lệ.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleLogin(),
                              decoration: InputDecoration(
                                hintText: 'Nhập mật khẩu',
                                hintStyle: const TextStyle(color: AppTheme.hintText, fontSize: 15),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.hintText, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AppTheme.hintText,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.black.withOpacity(0.06), width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppTheme.red, width: 1.5),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppTheme.red, width: 1.5),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vui lòng nhập mật khẩu.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Remember me and forgot password
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const CloudmoodForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Quên mật khẩu?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.darkText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B), // Dark slate/black button
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Đăng nhập',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Or login with divider
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.black.withOpacity(0.06), thickness: 1.5)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'Hoặc đăng nhập bằng',
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.35),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.black.withOpacity(0.06), thickness: 1.5)),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Social login buttons
                            Row(
                              children: [
                                // Google Button
                                Expanded(
                                  child: SizedBox(
                                    height: 52,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: AppTheme.darkText,
                                        side: BorderSide(color: Colors.black.withOpacity(0.06), width: 1.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      onPressed: _handleGoogleSignIn,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            'assets/images/google.png',
                                            height: 20,
                                            errorBuilder: (c, e, s) => Image.network(
                                              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                                              height: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Google',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'SDK_SC_Web-Heavy',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Facebook Button
                                Expanded(
                                  child: SizedBox(
                                    height: 52,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: AppTheme.darkText,
                                        side: BorderSide(color: Colors.black.withOpacity(0.06), width: 1.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      onPressed: _handleFacebookSignIn,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.facebook,
                                            color: Color(0xFF1877F2),
                                            size: 22,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Facebook',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'SDK_SC_Web-Heavy',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 36),

                            // Create account link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Chưa có tài khoản? ",
                                  style: TextStyle(
                                    color: AppTheme.subtitleText,
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const CloudmoodRegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Đăng ký ngay',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
