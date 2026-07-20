import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  int _step = 1;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (_step > 1) {
              setState(() => _step--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              _step == 1 ? 'Forgot Password?' : 'Reset Password',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 12),
            Text(
              _step == 1
                  ? 'Enter your email address and we\'ll send you a code to reset your password.'
                  : 'Enter the code sent to your email and your new password.',
              style: TextStyle(fontSize: 15, color: tc.subtitle, height: 1.5),
            ),
            const SizedBox(height: 36),
            if (_step == 1) ...[
              Text('Email Address', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.text)),
              const SizedBox(height: 12),
              Container(
                height: 55,
                decoration: BoxDecoration(
                  color: tc.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: tc.border),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Icon(Icons.email_outlined, size: 20, color: tc.hint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'andrew@email.com',
                          hintStyle: TextStyle(color: tc.hint, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              AppButton(
                text: 'Send Reset Code',
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (_emailController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter your email'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        setState(() => _isLoading = true);
                        try {
                          await AuthService().requestPasswordReset(
                            email: _emailController.text.trim(),
                          );
                          if (mounted) setState(() { _step = 2; _isLoading = false; });
                        } on Exception catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                            );
                            setState(() => _isLoading = false);
                          }
                        }
                      },
                icon: Icons.send_rounded,
              ),
            ] else ...[
              Text('Verification Code', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.text)),
              const SizedBox(height: 12),
              Container(
                height: 55,
                decoration: BoxDecoration(
                  color: tc.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: tc.border),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Icon(Icons.pin_rounded, size: 20, color: tc.hint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter 6-digit code',
                          hintStyle: TextStyle(color: tc.hint, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('New Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.text)),
              const SizedBox(height: 12),
              Container(
                height: 55,
                decoration: BoxDecoration(
                  color: tc.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: tc.border),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Icon(Icons.lock_outline_rounded, size: 20, color: tc.hint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter new password',
                          hintStyle: TextStyle(color: tc.hint, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Confirm Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.text)),
              const SizedBox(height: 12),
              Container(
                height: 55,
                decoration: BoxDecoration(
                  color: tc.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: tc.border),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Icon(Icons.lock_outline_rounded, size: 20, color: tc.hint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Confirm new password',
                          hintStyle: TextStyle(color: tc.hint, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              AppButton(
                text: 'Reset Password',
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (_otpController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter the verification code'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        if (_passwordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a new password'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        if (_passwordController.text != _confirmPasswordController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        setState(() => _isLoading = true);
                        try {
                          await AuthService().confirmPasswordReset(
                            token: _otpController.text.trim(),
                            newPassword: _passwordController.text,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password reset successfully'), backgroundColor: AppColors.success),
                            );
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        } on Exception catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                            );
                            setState(() => _isLoading = false);
                          }
                        }
                      },
                icon: Icons.check_rounded,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : () => setState(() => _step = 1),
                  child: const Text('Change email address', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
