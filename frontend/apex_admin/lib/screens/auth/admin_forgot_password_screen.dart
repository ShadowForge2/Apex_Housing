import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/loading_overlay.dart';
import '../../services/admin_auth_service.dart';
import '../../services/exceptions.dart';

class AdminForgotPasswordScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const AdminForgotPasswordScreen({super.key, required this.onComplete});

  @override
  State<AdminForgotPasswordScreen> createState() => _AdminForgotPasswordScreenState();
}

class _AdminForgotPasswordScreenState extends State<AdminForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  int _step = 1;
  String _email = '';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _otpComplete = false;

  int _cooldownSeconds = 60;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownSeconds = 60;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email');
      return;
    }

    bool success = false;
    await runWithLoading(
      context,
      action: () async {
        try {
          await AdminAuthService().requestPasswordReset(email: email);
          success = true;
        } on ApiException catch (e) {
          if (mounted) _showError(e.message);
        } catch (e) {
          if (mounted) _showError('Failed to send reset code. Please try again.');
        }
      },
      message: 'Sending reset code...',
    );

    if (success && mounted) {
      setState(() {
        _email = email;
        _step = 2;
      });
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset code sent to $email'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _resendOtp() async {
    if (_cooldownSeconds > 0) return;

    bool success = false;
    await runWithLoading(
      context,
      action: () async {
        try {
          await AdminAuthService().requestPasswordReset(email: _email);
          success = true;
        } on ApiException catch (e) {
          if (mounted) _showError(e.message);
        } catch (e) {
          if (mounted) _showError('Failed to resend code. Please try again.');
        }
      },
      message: 'Resending code...',
    );

    if (success && mounted) {
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Code resent to $_email'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  Future<void> _resetPassword() async {
    final otp = _otpCode;
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (otp.length < 6) {
      _showError('Please enter the 6-digit code');
      return;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match');
      return;
    }

    bool success = false;
    await runWithLoading(
      context,
      action: () async {
        try {
          await AdminAuthService().resetPassword(
            email: _email,
            code: otp,
            newPassword: password,
          );
          success = true;
        } on ApiException catch (e) {
          if (mounted) _showError(e.message);
        } catch (e) {
          if (mounted) _showError('Password reset failed. Please try again.');
        }
      },
      message: 'Resetting password...',
    );

    if (success && mounted) {
      _cooldownTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successful! Please login.'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onComplete();
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              GestureDetector(
                onTap: () {
                  if (_step == 2) {
                    _cooldownTimer?.cancel();
                    setState(() => _step = 1);
                  } else {
                    widget.onComplete();
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 28),
              if (_step == 1) _buildEmailStep() else _buildResetStep(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Forgot Password?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the email address associated with your admin account. We\'ll send you a code to reset your password.',
          style: TextStyle(fontSize: 15, color: AppColors.subtitle, height: 1.4),
        ),
        const SizedBox(height: 40),
        const Text('Email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 10),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendOtp(),
          decoration: InputDecoration(
            hintText: 'Enter your admin email',
            hintStyle: const TextStyle(color: AppColors.hint),
            filled: true,
            fillColor: AppColors.surface,
            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.hint, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              elevation: 0,
            ),
            child: const Text('Send Reset Code', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildResetStep() {
    final bool canResend = _cooldownSeconds == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reset Password',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to $_email and your new password.',
          style: TextStyle(fontSize: 15, color: AppColors.subtitle, height: 1.4),
        ),
        const SizedBox(height: 36),

        const Text('Verification Code', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            final isComplete = _otpComplete;
            return SizedBox(
              width: 48,
              height: 56,
              child: TextField(
                controller: _otpControllers[i],
                focusNode: _otpFocusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: isComplete ? AppColors.success : AppColors.border,
                      width: isComplete ? 2 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: isComplete ? AppColors.success : AppColors.border,
                      width: isComplete ? 2 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(
                      color: isComplete ? AppColors.success : AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && i < 5) {
                    _otpFocusNodes[i + 1].requestFocus();
                  } else if (val.isEmpty && i > 0) {
                    _otpFocusNodes[i - 1].requestFocus();
                  }

                  final code = _otpControllers.map((c) => c.text).join();
                  final nowComplete = code.length == 6;
                  if (nowComplete != _otpComplete) {
                    setState(() => _otpComplete = nowComplete);
                    if (nowComplete) {
                      _confirmPasswordFocusNode.requestFocus();
                    }
                  }
                },
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        if (_otpComplete)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 18),
              const SizedBox(width: 6),
              Text(
                'Code verified',
                style: TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),

        Center(
          child: canResend
              ? GestureDetector(
                  onTap: _resendOtp,
                  child: const Text(
                    'Resend Code',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : Text(
                  'Resend code in ${_cooldownSeconds}s',
                  style: TextStyle(
                    color: AppColors.subtitle,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),

        const SizedBox(height: 32),
        const Text('New Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
          decoration: InputDecoration(
            hintText: 'Enter new password',
            hintStyle: const TextStyle(color: AppColors.hint),
            filled: true,
            fillColor: AppColors.surface,
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.hint, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.hint, size: 20),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),

        const SizedBox(height: 20),
        const Text('Confirm Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 10),
        TextField(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocusNode,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _resetPassword(),
          decoration: InputDecoration(
            hintText: 'Confirm new password',
            hintStyle: const TextStyle(color: AppColors.hint),
            filled: true,
            fillColor: AppColors.surface,
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.hint, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.hint, size: 20),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),

        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              elevation: 0,
            ),
            child: const Text('Reset Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
