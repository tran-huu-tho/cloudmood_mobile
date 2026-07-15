import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

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
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Simulate sending reset instructions
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      final email = _emailController.text.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã gửi liên kết khôi phục tới $email!'),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    });
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
                            maxHeight: size.height * 0.35,
                          ),
                          child: Image.asset(
                            'assets/images/forgot_illustration.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.lock_reset_rounded,
                                    size: 80,
                                    color: AppTheme.primaryLight,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Title
                    FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quên mật khẩu? Khôi phục\ntruy cập tại đây',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                height: 1.3,
                                color: AppTheme.darkText,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nhập địa chỉ email của bạn bên dưới. Chúng tôi sẽ gửi một liên kết để bạn khôi phục lại mật khẩu tài khoản.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.subtitleText,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Email Input
                    FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleSubmit(),
                              decoration: InputDecoration(
                                hintText: 'Nhập địa chỉ email',
                                hintStyle: const TextStyle(
                                  color: AppTheme.hintText,
                                  fontSize: 15,
                                ),
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: AppTheme.hintText,
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.black.withOpacity(0.06),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppTheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppTheme.red,
                                    width: 1.5,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: AppTheme.red,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vui lòng nhập địa chỉ email';
                                }
                                final regex =
                                    RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                if (!regex.hasMatch(value.trim())) {
                                  return 'Định dạng email không hợp lệ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSubmit,
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
                                        'Gửi yêu cầu',
                                        style: TextStyle(
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
