import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class CloudmoodForgotPasswordScreen extends StatefulWidget {
  const CloudmoodForgotPasswordScreen({super.key});

  @override
  State<CloudmoodForgotPasswordScreen> createState() =>
      _CloudmoodForgotPasswordScreenState();
}

class _CloudmoodForgotPasswordScreenState
    extends State<CloudmoodForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _codeSent = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  final AuthService _authService = AuthService();

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _cooldownTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 45;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        _cooldownTimer?.cancel();
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    if (!_codeSent) {
      final response = await _authService.sendForgotPasswordCode(email: email);
      setState(() => _isLoading = false);

      if (mounted) {
        if (response['success'] as bool) {
          _startCooldown();
          setState(() {
            _codeSent = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] as String),
              backgroundColor: AppTheme.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
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
    } else {
      final code = _otpController.text.trim();
      final newPassword = _newPasswordController.text;

      final response = await _authService.resetForgotPassword(
        email: email,
        code: code,
        newPassword: newPassword,
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
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final email = _emailController.text.trim();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE0F2FE), // Very light soft blue
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
                    // Back Button
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
                    const SizedBox(height: 24),

                    // Top Illustration
                    Center(
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: size.height * 0.28,
                          ),
                          child: Image.asset(
                            'assets/images/forgot_illustration.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.lock_reset_rounded,
                                    size: 64,
                                    color: AppTheme.primaryLight,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _codeSent
                                  ? 'Xác thực & Đặt lại\nmật khẩu mới'
                                  : 'Quên mật khẩu? Khôi phục\ntruy cập tại đây',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                height: 1.3,
                                color: AppTheme.darkText,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _codeSent
                                  ? 'Nhập mã xác thực 6 chữ số đã gửi đến email của bạn kèm theo mật khẩu mới.'
                                  : 'Nhập địa chỉ email của bạn bên dưới. Chúng tôi sẽ gửi một mã xác thực gồm 6 chữ số để bạn khôi phục lại mật khẩu.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.subtitleText,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Input Fields Block
                    FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: Column(
                          children: [
                            if (!_codeSent) ...[
                              // Email Input (Step 1)
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleSubmit(),
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
                                    return 'Vui lòng nhập địa chỉ email';
                                  }
                                  final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                  if (!regex.hasMatch(value.trim())) {
                                    return 'Định dạng email không hợp lệ';
                                  }
                                  return null;
                                },
                              ),
                            ] else ...[
                              // Info row with Back to edit
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Mã đã gửi đến: $email',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.subtitleText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => _codeSent = false),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Đổi email',
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // OTP input (Step 2)
                              TextFormField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 6,
                                  color: AppTheme.darkText,
                                ),
                                decoration: InputDecoration(
                                  hintText: '000000',
                                  hintStyle: TextStyle(
                                    color: AppTheme.hintText.withOpacity(0.5),
                                    letterSpacing: 6,
                                  ),
                                  counterText: '',
                                  prefixIcon: const Icon(Icons.pin_rounded, color: AppTheme.hintText, size: 20),
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
                                    return 'Vui lòng nhập mã xác thực.';
                                  }
                                  if (value.trim().length != 6) {
                                    return 'Mã xác thực phải gồm 6 chữ số.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // New Password input (Step 2)
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: _obscureNewPassword,
                                decoration: InputDecoration(
                                  hintText: 'Nhập mật khẩu mới',
                                  hintStyle: const TextStyle(color: AppTheme.hintText, fontSize: 15),
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.hintText, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: AppTheme.hintText,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
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
                                    return 'Vui lòng nhập mật khẩu mới.';
                                  }
                                  if (value.length < 8) {
                                    return 'Mật khẩu phải có ít nhất 8 ký tự.';
                                  }
                                  if (!value.contains(RegExp(r'[A-Z]'))) {
                                    return 'Mật khẩu phải có ít nhất 1 chữ viết hoa.';
                                  }
                                  if (!value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
                                    return 'Mật khẩu phải có ít nhất 1 ký tự đặc biệt.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Confirm Password input (Step 2)
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleSubmit(),
                                decoration: InputDecoration(
                                  hintText: 'Xác nhận mật khẩu mới',
                                  hintStyle: const TextStyle(color: AppTheme.hintText, fontSize: 15),
                                  prefixIcon: const Icon(Icons.lock_rounded, color: AppTheme.hintText, size: 20),
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
                                    return 'Vui lòng xác nhận mật khẩu mới.';
                                  }
                                  if (value != _newPasswordController.text) {
                                    return 'Mật khẩu xác nhận không khớp.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Resend text button
                              TextButton(
                                onPressed: (_isLoading || _cooldownSeconds > 0)
                                    ? null
                                    : () async {
                                        _startCooldown();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Đang gửi lại mã xác thực...'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        await _authService.sendForgotPasswordCode(email: email);
                                      },
                                child: Text(
                                  _cooldownSeconds > 0
                                      ? 'Gửi lại mã xác thực (${_cooldownSeconds}s)'
                                      : 'Gửi lại mã xác thực',
                                  style: TextStyle(
                                    color: _cooldownSeconds > 0 ? AppTheme.subtitleText : AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
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
                                    : Text(
                                        _codeSent ? 'Xác nhận & Đặt lại' : 'Gửi mã xác thực',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
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
            ),
          ),
        ),
      ),
    );
  }
}
