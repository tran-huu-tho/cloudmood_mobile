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
  bool _agreeToTerms = false;
  bool _isLoading = false;

  // Password strength variables
  String _passwordStrength = '';
  Color _passwordStrengthColor = Colors.grey;
  double _passwordStrengthPercent = 0.0;
  IconData _passwordStrengthIcon = Icons.lock_outline;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkPasswordStrength);
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.removeListener(_checkPasswordStrength);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // Visual password strength calculator
  void _checkPasswordStrength() {
    final pwd = _passwordController.text;
    if (pwd.isEmpty) {
      setState(() {
        _passwordStrength = '';
        _passwordStrengthColor = Colors.grey;
        _passwordStrengthPercent = 0.0;
        _passwordStrengthIcon = Icons.lock_outline;
      });
      return;
    }

    if (pwd.length < 6) {
      setState(() {
        _passwordStrength = 'Yếu — ít nhất 6 ký tự';
        _passwordStrengthColor = AppTheme.red;
        _passwordStrengthPercent = 0.25;
        _passwordStrengthIcon = Icons.lock_open_rounded;
      });
      return;
    }

    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(pwd);
    final hasDigits = RegExp(r'[0-9]').hasMatch(pwd);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pwd);

    if (hasLetters && hasDigits && hasSpecial && pwd.length >= 8) {
      setState(() {
        _passwordStrength = 'Mạnh — tuyệt vời!';
        _passwordStrengthColor = AppTheme.green;
        _passwordStrengthPercent = 1.0;
        _passwordStrengthIcon = Icons.lock_rounded;
      });
    } else if (hasLetters && hasDigits) {
      setState(() {
        _passwordStrength = 'Trung bình — thêm ký tự đặc biệt';
        _passwordStrengthColor = AppTheme.amber;
        _passwordStrengthPercent = 0.65;
        _passwordStrengthIcon = Icons.lock_rounded;
      });
    } else {
      setState(() {
        _passwordStrength = 'Yếu — thêm số và ký tự đặc biệt';
        _passwordStrengthColor = AppTheme.red;
        _passwordStrengthPercent = 0.35;
        _passwordStrengthIcon = Icons.lock_open_rounded;
      });
    }
  }

  // Handle register submission
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý với điều khoản sử dụng.'),
          backgroundColor: AppTheme.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final response = await _authService.register(
      fullName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (response['success'] as bool) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] as String),
            backgroundColor: AppTheme.green,
          ),
        );
        Navigator.of(context)
          ..pop()
          ..pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] as String),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Top gradient banner ──────────────────────────────────
          Container(
            width: double.infinity,
            height: size.height * 0.28,
            decoration: const BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -40,
                  right: -30,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(12),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        // Back button
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: AppTheme.glassDecoration(
                              opacity: 0.2,
                              radius: 12,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable form ─────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.10),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tạo tài khoản',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Bắt đầu hành trình của bạn cùng cloudmood',
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: AppTheme.premiumCardDecoration(),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Progress indicator
                              Row(
                                children: [
                                  _buildStep(1, 'Thông tin', true, false),
                                  _buildStepConnector(true),
                                  _buildStep(2, 'Bảo mật', false, false),
                                  _buildStepConnector(false),
                                  _buildStep(3, 'Xác nhận', false, false),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Full Name
                              TextFormField(
                                controller: _nameController,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                decoration: AppTheme.inputDecoration(
                                  hintText: 'Họ và tên',
                                  prefixIcon: Icons.person_outline_rounded,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Vui lòng nhập họ và tên.';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'Tên ít nhất 3 ký tự.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: AppTheme.inputDecoration(
                                  hintText: 'Địa chỉ email',
                                  prefixIcon: Icons.email_outlined,
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
                              const SizedBox(height: 12),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                decoration: AppTheme.inputDecoration(
                                  hintText: 'Mật khẩu',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: AppTheme.subtitleText,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Vui lòng nhập mật khẩu.';
                                  }
                                  if (value.length < 6) {
                                    return 'Mật khẩu ít nhất 6 ký tự.';
                                  }
                                  return null;
                                },
                              ),

                              // Strength indicator
                              if (_passwordStrength.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(
                                      _passwordStrengthIcon,
                                      size: 14,
                                      color: _passwordStrengthColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _passwordStrength,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _passwordStrengthColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _passwordStrengthPercent,
                                    backgroundColor: AppTheme.border,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _passwordStrengthColor,
                                    ),
                                    minHeight: 5,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),

                              // Confirm Password
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleRegister(),
                                decoration: AppTheme.inputDecoration(
                                  hintText: 'Xác nhận mật khẩu',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: AppTheme.subtitleText,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Vui lòng xác nhận mật khẩu.';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Mật khẩu không khớp.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Terms checkbox
                              GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _agreeToTerms = !_agreeToTerms,
                                  );
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: _agreeToTerms
                                            ? AppTheme.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _agreeToTerms
                                              ? AppTheme.primary
                                              : AppTheme.border,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: _agreeToTerms
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 14,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.bodyText,
                                          ),
                                          children: [
                                            const TextSpan(
                                              text: 'Tôi đồng ý với ',
                                            ),
                                            TextSpan(
                                              text: 'Điều khoản sử dụng',
                                              style: const TextStyle(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const TextSpan(text: ' và '),
                                            TextSpan(
                                              text: 'Chính sách bảo mật',
                                              style: const TextStyle(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Register Button
                              GestureDetector(
                                onTap: _isLoading ? null : _handleRegister,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 52,
                                  width: double.infinity,
                                  decoration: _isLoading
                                      ? BoxDecoration(
                                          color: AppTheme.primary.withAlpha(
                                            160,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        )
                                      : AppTheme.gradientButtonDecoration(),
                                  child: Center(
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Text(
                                            'Tạo tài khoản',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: 0.3,
                                            ),
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

                  const SizedBox(height: 24),

                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Đã có tài khoản? ',
                        style: TextStyle(
                          color: AppTheme.subtitleText,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Đăng nhập ngay',
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
    );
  }

  Widget _buildStep(int step, String label, bool isActive, bool isDone) {
    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isDone
                  ? AppTheme.primary
                  : AppTheme.surfaceVariant,
              border: Border.all(
                color: isActive ? AppTheme.primary : AppTheme.border,
                width: 1.5,
              ),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : AppTheme.subtitleText,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isActive ? AppTheme.primary : AppTheme.hintText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.only(bottom: 16),
        color: isActive ? AppTheme.primary : AppTheme.border,
      ),
    );
  }
}
