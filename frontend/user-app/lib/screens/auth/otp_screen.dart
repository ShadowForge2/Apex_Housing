import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../services/auth_service.dart';

class OTPScreen extends StatefulWidget {
  final VoidCallback onVerified;
  final String? email;

  const OTPScreen({super.key, required this.onVerified, this.email});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  int _resendSeconds = 120;
  bool _canResend = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
        return true;
      }
      setState(() => _canResend = true);
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tc.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: tc.border),
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Verify Email',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the 6-digit code sent to your email',
                    style: TextStyle(fontSize: 15, color: tc.subtitle),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) => _otpField(i)),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              final otpCode = _controllers.map((c) => c.text).join();
                              if (otpCode.length != 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter the full 6-digit code'), backgroundColor: Colors.red),
                                );
                                return;
                              }
                              setState(() => _isLoading = true);
                              try {
                                await AuthService().verifyOtp(
                                  code: otpCode,
                                  email: widget.email,
                                );
                                if (mounted) {
                                  widget.onVerified();
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
                      child: const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: _canResend
                        ? GestureDetector(
                            onTap: () async {
                              setState(() {
                                _resendSeconds = 120;
                                _canResend = false;
                              });
                              _startTimer();
                              try {
                                if (widget.email != null) {
                                  await AuthService().sendOtp(email: widget.email!);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('OTP code resent'), backgroundColor: Colors.green),
                                  );
                                }
                              } on Exception catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              'Resend Code',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          )
                        : Text(
                            'Resend in ${_resendSeconds ~/ 60}:${(_resendSeconds % 60).toString().padLeft(2, '0')}',
                            style: TextStyle(color: tc.hint, fontSize: 14),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) const ApexLoadingFull(label: 'Verifying...'),
        ],
      ),
    );
  }

  Widget _otpField(int index) {
    return SizedBox(
      width: 52,
      height: 60,
      child: TextField(
        controller: _controllers[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          if (value.length == 1 && index < 5) {
            FocusScope.of(context).nextFocus();
          } else if (value.isEmpty && index > 0) {
            FocusScope.of(context).previousFocus();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }
}
