import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../theme/theme_colors.dart';
import '../../services/user_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _userService = UserService();
  bool _currentPassVisible = false;
  bool _newPassVisible = false;
  bool _confirmPassVisible = false;
  bool _newPassValid = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _newPassController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.removeListener(_validatePassword);
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final v = _newPassController.text;
    final hasMin = v.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(v);
    final hasDigit = RegExp(r'[0-9]').hasMatch(v);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(v);
    setState(() => _newPassValid = hasMin && hasUpper && hasDigit && hasSpecial);
  }

  Future<void> _savePassword() async {
    if (!_newPassValid) return;
    if (_newPassController.text != _confirmPassController.text) {
      _showError('Passwords do not match');
      return;
    }
    if (_currentPassController.text.isEmpty) {
      _showError('Please enter your current password');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _userService.changePassword(
        currentPassword: _currentPassController.text,
        newPassword: _newPassController.text,
      );
      _showSuccess('Password changed successfully');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Failed to change password: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Toast(message: msg, color: AppColors.error, shadow: AppColors.error.withValues(alpha: 0.35), onDismiss: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  void _showSuccess(String msg) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Toast(message: msg, color: AppColors.success, shadow: AppColors.success.withValues(alpha: 0.35), onDismiss: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Change Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('Change Password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tc.text)),
            const SizedBox(height: 8),
            Text('Enter your current password and choose a new one.', style: TextStyle(fontSize: 14, color: tc.subtitle, height: 1.5)),
            const SizedBox(height: 28),
            Text('Current Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc.hint)),
            const SizedBox(height: 8),
            TextField(
              controller: _currentPassController,
              obscureText: !_currentPassVisible,
              style: TextStyle(fontSize: 15, color: tc.text),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: tc.hint),
                suffixIcon: IconButton(
                  icon: Icon(_currentPassVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: tc.hint),
                  onPressed: () => setState(() => _currentPassVisible = !_currentPassVisible),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc.hint)),
            const SizedBox(height: 8),
            TextField(
              controller: _newPassController,
              obscureText: !_newPassVisible,
              style: TextStyle(fontSize: 15, color: tc.text),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: tc.hint),
                suffixIcon: IconButton(
                  icon: Icon(_newPassVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: tc.hint),
                  onPressed: () => setState(() => _newPassVisible = !_newPassVisible),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _passwordRequirements(tc),
            const SizedBox(height: 20),
            Text('Confirm New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc.hint)),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPassController,
              obscureText: !_confirmPassVisible,
              style: TextStyle(fontSize: 15, color: tc.text),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: tc.hint),
                suffixIcon: IconButton(
                  icon: Icon(_confirmPassVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: tc.hint),
                  onPressed: () => setState(() => _confirmPassVisible = !_confirmPassVisible),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_newPassValid && !_isSubmitting) ? _savePassword : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _newPassValid ? AppColors.primary : tc.border,
                  disabledBackgroundColor: tc.border,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: ApexLoading(size: 20),
                      )
                    : Text('Save Password', style: TextStyle(color: _newPassValid ? Colors.white : tc.hint, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordRequirements(ThemeColors tc) {
    final v = _newPassController.text;
    final hasMin = v.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(v);
    final hasDigit = RegExp(r'[0-9]').hasMatch(v);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _req('At least 8 characters', hasMin, tc),
        _req('One uppercase letter', hasUpper, tc),
        _req('One number', hasDigit, tc),
        _req('One special character', hasSpecial, tc),
      ],
    );
  }

  Widget _req(String text, bool met, ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle_rounded : Icons.circle_outlined, size: 14, color: met ? AppColors.success : tc.hint),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12, color: met ? AppColors.success : tc.hint)),
        ],
      ),
    );
  }
}

class _Toast extends StatefulWidget {
  final String message;
  final Color color;
  final Color shadow;
  final VoidCallback onDismiss;
  const _Toast({required this.message, required this.color, required this.shadow, required this.onDismiss});

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
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
                boxShadow: [BoxShadow(blurRadius: 16, color: widget.shadow)],
              ),
              child: Row(
                children: [
                  Icon(widget.color == AppColors.success ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 20),
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
