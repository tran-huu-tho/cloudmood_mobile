import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class CloudmoodRegisterScreen extends StatefulWidget {
  const CloudmoodRegisterScreen({super.key});

  @override
  State<CloudmoodRegisterScreen> createState() =>
      _CloudmoodRegisterScreenState();
}

class _CloudmoodRegisterScreenState extends State<CloudmoodRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // Handle register submission
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final response = await _authService.register(
      fullName: _nameController.text.trim(),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Back button and Cloud graphics
                    Row(
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
                    const SizedBox(height: 16),

                    // Clouds & Header Theme
                    Center(
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                left: 20,
                                top: 10,
                                child: Icon(Icons.cloud_rounded, size: 54, color: Colors.white.withOpacity(0.7)),
                              ),
                              Positioned(
                                right: 30,
                                top: 20,
                                child: Icon(Icons.cloud_rounded, size: 72, color: Colors.white.withOpacity(0.85)),
                              ),
                              Positioned(
                                left: size.width * 0.35,
                                top: 40,
                                child: Icon(Icons.cloud_rounded, size: 48, color: Colors.white.withOpacity(0.6)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Title
                    FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đăng ký để Khám phá\nvà Trải nghiệm',
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
                    const SizedBox(height: 28),

                    // Form Fields
                    FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: Column(
                          children: [
                            // Full Name
                            TextFormField(
                              controller: _nameController,
                              keyboardType: TextInputType.name,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: 'Nhập họ và tên',
                                hintStyle: const TextStyle(color: AppTheme.hintText, fontSize: 15),
                                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.hintText, size: 20),
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
                                  return 'Vui lòng nhập họ và tên.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Email
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
                                  return 'Vui lòng nhập địa chỉ email.';
                                }
                                final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                if (!regex.hasMatch(value.trim())) {
                                  return 'Định dạng email không hợp lệ.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
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
                                if (value.length < 6) {
                                  return 'Mật khẩu phải chứa ít nhất 6 ký tự.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Confirm Password
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleRegister(),
                              decoration: InputDecoration(
                                hintText: 'Xác nhận mật khẩu',
                                hintStyle: const TextStyle(color: AppTheme.hintText, fontSize: 15),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.hintText, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AppTheme.hintText,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
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
                                  return 'Vui lòng xác nhận mật khẩu.';
                                }
                                if (value != _passwordController.text) {
                                  return 'Mật khẩu xác nhận không khớp.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Remember me checkbox
                            Row(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: const Color(0xFF1E293B),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    side: BorderSide(
                                      color: Colors.black.withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                    onChanged: (value) => setState(() => _rememberMe = value ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Ghi nhớ đăng nhập',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.subtitleText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Sign Up Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleRegister,
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
                                        'Đăng ký',
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
                                    'Hoặc đăng ký bằng',
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
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Đăng ký bằng Google sẽ sớm ra mắt!'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
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
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Đăng ký bằng Facebook sẽ sớm ra mắt!'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
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

                            // Already have an account link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Đã có tài khoản? ",
                                  style: TextStyle(
                                    color: AppTheme.subtitleText,
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    'Đăng nhập',
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
