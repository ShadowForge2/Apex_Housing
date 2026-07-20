import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../theme/theme_colors.dart';
import '../../services/token_storage.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';

class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() => _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> with SingleTickerProviderStateMixin {
  final _localAuth = LocalAuthentication();
  bool _enabled = false;
  bool _scanning = false;
  bool _hasHardware = false;
  bool _canCheckBiometrics = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _initBiometric();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initBiometric() async {
    final storage = TokenStorage();
    final enabled = await storage.isBiometricEnabled();
    bool hasHardware = false;
    bool canCheck = false;
    try {
      hasHardware = await _localAuth.canCheckBiometrics;
      canCheck = await _localAuth.isDeviceSupported();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _enabled = enabled;
        _hasHardware = hasHardware;
        _canCheckBiometrics = canCheck;
      });
    }
  }

  Future<void> _toggleBiometric() async {
    if (_enabled) {
      await _disableBiometric();
    } else {
      await _enableBiometric();
    }
  }

  Future<void> _enableBiometric() async {
    if (!_hasHardware || !_canCheckBiometrics) {
      _showError('This device does not support biometric authentication');
      return;
    }

    final storage = TokenStorage();
    final email = await storage.getUserEmail();
    if (email == null || email.isEmpty) {
      _showError('No account found. Please sign in first.');
      return;
    }

    setState(() => _scanning = true);

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to enable biometric sign-in',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!authenticated) {
        if (mounted) setState(() => _scanning = false);
        return;
      }

      final password = await _showPasswordDialog();
      if (password == null || password.isEmpty) {
        if (mounted) setState(() => _scanning = false);
        return;
      }

      final authService = AuthService();
      final result = await authService.login(email: email, password: password);

      final refreshToken = result['refresh_token'] as String?;
      if (refreshToken != null) {
        await storage.setBiometricEnabled(email: email, refreshToken: refreshToken);
      }

      try {
        final userService = UserService();
        await userService.updatePreference(biometricEnabled: true);
      } catch (e) {
        debugPrint('BiometricSettings: Failed to sync preference: $e');
      }

      if (mounted) {
        setState(() {
          _scanning = false;
          _enabled = true;
        });
        _showToast('Biometric sign-in enabled', AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        _showError('Failed to enable biometric: ${e.toString()}');
      }
    }
  }

  Future<void> _disableBiometric() async {
    final storage = TokenStorage();
    await storage.clearBiometric();
    try {
      final userService = UserService();
      await userService.updatePreference(biometricEnabled: false);
    } catch (e) {
      debugPrint('BiometricSettings: Failed to sync disable preference: $e');
    }
    if (mounted) {
      setState(() => _enabled = false);
      _showToast('Biometric sign-in disabled', AppColors.warning);
    }
  }

  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Enter your password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _showError(String msg) {
    _showToast(msg, AppColors.error);
  }

  void _showToast(String msg, Color color) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BiometricToast(message: msg, color: color, onDismiss: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Biometric Login'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            _buildFingerprintVisual(tc),
            const SizedBox(height: 32),
            Text(
              _scanning ? 'Scanning...' : _enabled ? 'Biometric Enabled' : 'Enable Biometric Sign-In',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tc.text),
            ),
            const SizedBox(height: 8),
            Text(
              !_hasHardware || !_canCheckBiometrics
                  ? 'This device does not support fingerprint or face authentication'
                  : _scanning
                      ? 'Place your finger on the sensor'
                      : _enabled
                          ? 'Sign in using your fingerprint instead of password'
                          : 'Use your fingerprint to sign in quickly without entering your password',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: tc.subtitle, height: 1.5),
            ),
            const SizedBox(height: 40),
            if (_enabled && !_scanning) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 22, color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Biometric Sign-In Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success)),
                          const SizedBox(height: 2),
                          Text('You can now sign in with your fingerprint', style: TextStyle(fontSize: 12, color: AppColors.success.withValues(alpha: 0.8))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_scanning) ...[
              const SizedBox(
                width: 22,
                height: 22,
                child: ApexLoading(size: 20),
              ),
              const SizedBox(height: 24),
            ],
            if (_hasHardware && _canCheckBiometrics) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _scanning ? null : _toggleBiometric,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _enabled ? AppColors.error : AppColors.primary,
                    disabledBackgroundColor: tc.border,
                  ),
                  child: _scanning
                      ? const Text('Scanning...', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))
                      : Text(
                          _enabled ? 'Disable Biometric' : 'Enable Biometric',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 22, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Biometric hardware not available on this device',
                        style: TextStyle(fontSize: 13, color: AppColors.error.withValues(alpha: 0.9)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            _buildInfoCard(tc),
          ],
        ),
      ),
    );
  }

  Widget _buildFingerprintVisual(ThemeColors tc) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final scale = _scanning ? 1.0 + (_pulseController.value * 0.08) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _scanning
                  ? AppColors.primary.withValues(alpha: 0.08 + _pulseController.value * 0.08)
                  : _enabled
                      ? AppColors.success.withValues(alpha: 0.08)
                      : tc.surfaceVariant,
              border: Border.all(
                color: _scanning
                    ? AppColors.primary.withValues(alpha: 0.2 + _pulseController.value * 0.2)
                    : _enabled
                        ? AppColors.success.withValues(alpha: 0.3)
                        : tc.border,
                width: 2,
              ),
            ),
            child: Icon(
              _scanning || _enabled ? Icons.fingerprint_rounded : Icons.fingerprint_outlined,
              size: 56,
              color: _scanning ? AppColors.primary : _enabled ? AppColors.success : tc.hint,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(ThemeColors tc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: tc.hint),
              const SizedBox(width: 8),
              Text('How it works', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc.text)),
            ],
          ),
          const SizedBox(height: 10),
          _infoItem('Your fingerprint is stored securely on your device', tc),
          const SizedBox(height: 4),
          _infoItem('APEX Housing never has access to your biometric data', tc),
          const SizedBox(height: 4),
          _infoItem('Your refresh token is encrypted in secure storage', tc),
          const SizedBox(height: 4),
          _infoItem('You can disable this feature at any time', tc),
        ],
      ),
    );
  }

  Widget _infoItem(String text, ThemeColors tc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: tc.hint)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: tc.subtitle, height: 1.4))),
      ],
    );
  }
}

class _BiometricToast extends StatefulWidget {
  final String message;
  final Color color;
  final VoidCallback onDismiss;
  const _BiometricToast({required this.message, required this.color, required this.onDismiss});

  @override
  State<_BiometricToast> createState() => _BiometricToastState();
}

class _BiometricToastState extends State<_BiometricToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _slide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.4, curve: Curves.easeOut)),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.15, curve: Curves.easeIn)),
    );
    _controller.forward();
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDismiss();
    });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 16;
    return Positioned(
      top: top, left: 24, right: 24,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [BoxShadow(blurRadius: 16, color: widget.color.withValues(alpha: 0.35))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.message, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
