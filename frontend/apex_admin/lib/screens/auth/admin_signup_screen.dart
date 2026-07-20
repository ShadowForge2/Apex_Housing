import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/loading_overlay.dart';
import '../../services/admin_auth_service.dart';
import '../../services/exceptions.dart';

class AdminSignupScreen extends StatefulWidget {
  final VoidCallback onSignup;
  final VoidCallback onGoToLogin;

  const AdminSignupScreen({
    super.key,
    required this.onSignup,
    required this.onGoToLogin,
  });

  @override
  State<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends State<AdminSignupScreen> {
  int _step = 1;
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _agreeTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _passwordsMatch {
    return _passwordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text;
  }

  bool get _canSubmit {
    return _agreeTerms &&
        _passwordsMatch &&
        _passwordController.text.length >= 8 &&
        _emailController.text.trim().isNotEmpty;
  }

  void _register() async {
    if (!_canSubmit) return;
    bool success = false;
    bool isResend = false;
    bool redirectToLogin = false;
    await runWithLoading(
      context,
      action: () async {
        try {
          final result = await AdminAuthService().register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            firstName: 'Admin',
            lastName: '',
          );
          final data = result['data'] as Map<String, dynamic>;
          isResend = data['resend_otp'] == true;
          redirectToLogin = data['redirect_to_login'] == true;
          success = true;
        } on ApiException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Registration failed: ${e.toString()}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
      message: 'Creating your account...',
    );
    if (success && mounted) {
      if (redirectToLogin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account already exists. Please login.'),
            backgroundColor: AppColors.primary,
          ),
        );
        widget.onGoToLogin();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isResend
                ? 'Account already exists but not verified. A new OTP has been sent!'
                : 'Account created! Check the backend terminal for your OTP code.'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() => _step = 2);
      }
    }
  }

  void _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter the 6-digit OTP code.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      await AdminAuthService().verifyOtp(
        email: _emailController.text.trim(),
        code: code,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email verified successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onSignup();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP verification failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _step == 1 ? _buildStep1() : _buildStep2(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryLight, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.person_add_outlined, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 32),
        Text(
          'Create Admin Account',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The first admin to register becomes the Super Admin',
          style: TextStyle(fontSize: 15, color: AppColors.subtitle),
        ),
        const SizedBox(height: 40),
        Text(
          'Email Address',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Enter your email address',
            hintStyle: TextStyle(color: AppColors.hint),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: AppRadius.smAll, borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: AppRadius.smAll, borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: AppRadius.smAll, borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Password',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: _obscure1,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Min 8 characters',
            hintStyle: TextStyle(color: AppColors.hint),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: AppRadius.smAll, borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: AppRadius.smAll, borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: AppRadius.smAll, borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.hint,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure1 = !_obscure1),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Confirm Password',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscure2,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Confirm your password',
            hintStyle: TextStyle(color: AppColors.hint),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: AppRadius.smAll, borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: AppRadius.smAll, borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: AppRadius.smAll, borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.hint,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure2 = !_obscure2),
            ),
          ),
        ),
        if (_passwordController.text.isNotEmpty && _confirmPasswordController.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _passwordsMatch ? Icons.check_circle : Icons.cancel,
                color: _passwordsMatch ? AppColors.success : AppColors.error,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _passwordsMatch ? 'Passwords match' : 'Passwords do not match',
                style: TextStyle(
                  fontSize: 12,
                  color: _passwordsMatch ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => setState(() => _agreeTerms = !_agreeTerms),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _agreeTerms,
                  onChanged: (val) => setState(() => _agreeTerms = val ?? false),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  side: BorderSide(color: AppColors.border),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'I agree to the Admin ',
                    style: TextStyle(fontSize: 13, color: AppColors.subtitle),
                    children: [
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _canSubmit ? _register : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              elevation: 0,
            ),
            child: Text('Create Account & Verify Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: GestureDetector(
            onTap: widget.onGoToLogin,
            child: Text.rich(
              TextSpan(
                text: 'Already have an account? ',
                style: TextStyle(fontSize: 14, color: AppColors.subtitle),
                children: [
                  TextSpan(
                    text: 'Login',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryLight, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 32),
        Text(
          'Verify Your Email',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to your email',
          style: TextStyle(fontSize: 15, color: AppColors.subtitle),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            _emailController.text.trim(),
            style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.smAll,
          ),
          child: Row(
            children: [
              Icon(Icons.terminal, color: AppColors.subtitle, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Check the backend terminal for the OTP code (in CONSOLE mode)',
                  style: TextStyle(fontSize: 12, color: AppColors.subtitle),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'OTP Code',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(color: AppColors.hint, letterSpacing: 8),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: AppRadius.smAll, borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: AppRadius.smAll, borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: AppRadius.smAll, borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            counterText: '',
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              elevation: 0,
            ),
            child: Text('Verify & Complete Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: GestureDetector(
            onTap: widget.onGoToLogin,
            child: Text.rich(
              TextSpan(
                text: 'Already have an account? ',
                style: TextStyle(fontSize: 14, color: AppColors.subtitle),
                children: [
                  TextSpan(
                    text: 'Login',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
