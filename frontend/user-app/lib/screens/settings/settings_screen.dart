import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_provider.dart';
import '../../theme/theme_colors.dart';
import '../../theme/text_scale_provider.dart';
import '../../services/notification_service.dart';
import '../../services/locale_service.dart';
import 'terms_of_service_screen.dart';
import 'reports_screen.dart';
import '../../widgets/loading_overlay.dart';
import '../profile/change_password_screen.dart';
import '../profile/biometric_settings_screen.dart';
import '../profile/help_center_screen.dart';
import '../profile/help_support_screen.dart';
import '../profile/privacy_policy_screen.dart';
import '../profile/profile_visibility_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotif = true;
  bool _emailNotif = true;
  bool _smsNotif = true;
  bool _isLoadingPrefs = true;
  bool _isSavingPush = false;
  bool _isSavingEmail = false;

  String _selectedLang = 'en';
  final _notifService = NotificationService();
  final _localeService = LocaleService();

  @override
  void initState() {
    super.initState();
    _selectedLang = _localeService.languageCode;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await _notifService.getPreferences();
      if (mounted) {
        setState(() {
          _pushNotif = prefs.pushEnabled;
          _emailNotif = prefs.emailEnabled;
          _isLoadingPrefs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPrefs = false);
    }
  }

  String _tr(String key) => _localeService.tr(key);

  void _showToast(String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SettingsToast(message: message, onDismiss: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  Future<void> _togglePush(bool value) async {
    setState(() { _pushNotif = value; _isSavingPush = true; });
    try {
      await _notifService.updatePreferences(pushEnabled: value);
      _showToast('${_tr("push_notifications")} ${value ? "enabled" : "disabled"}');
    } catch (e) {
      setState(() => _pushNotif = !value);
      _showToast('Failed to update push preference');
    } finally {
      if (mounted) setState(() => _isSavingPush = false);
    }
  }

  Future<void> _toggleEmail(bool value) async {
    setState(() { _emailNotif = value; _isSavingEmail = true; });
    try {
      await _notifService.updatePreferences(emailEnabled: value);
      _showToast('${_tr("email_notifications")} ${value ? "enabled" : "disabled"}');
    } catch (e) {
      setState(() => _emailNotif = !value);
      _showToast('Failed to update email preference');
    } finally {
      if (mounted) setState(() => _isSavingEmail = false);
    }
  }

  Future<void> _changeLanguage(String code, String label) async {
    setState(() => _selectedLang = code);
    await _localeService.setLanguage(code);
    if (mounted) {
      setState(() {});
      _showToast('Language set to $label');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final themeProvider = ThemeScope.of(context);
    final isDark = themeProvider.isDark;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: Text(_tr('settings'), style: TextStyle(color: tc.text)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: tc.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _section(_tr('notifications'), tc, [
              _switchItem(Icons.notifications_outlined, _tr('push_notifications'), _pushNotif, tc, (v) {
                _togglePush(v);
              }),
              _switchItem(Icons.email_outlined, _tr('email_notifications'), _emailNotif, tc, (v) {
                _toggleEmail(v);
              }),
              _switchItem(Icons.sms_outlined, _tr('sms_notifications'), _smsNotif, tc, (v) {
                setState(() => _smsNotif = v);
                _showToast('${_tr("sms_notifications")} ${v ? "enabled" : "disabled"}');
              }),
            ]),
            const SizedBox(height: 16),
            _section(_tr('appearance'), tc, [
              _darkModeSwitchItem(tc, isDark, themeProvider),
              _largeTextSwitchItem(tc, context),
            ]),
            const SizedBox(height: 16),
            _section(_tr('language'), tc, [
              _languageItem('English', 'en', tc),
              _languageItem('Yoruba', 'yo', tc),
              _languageItem('Pidgin', 'pcm', tc),
            ]),
            const SizedBox(height: 16),
            _section(_tr('privacy'), tc, [
              _item(Icons.lock_outline_rounded, _tr('change_password'), tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
              _item(Icons.fingerprint_rounded, _tr('biometric_login'), tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BiometricSettingsScreen()))),
              _item(Icons.visibility_outlined, _tr('profile_visibility'), tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileVisibilityScreen()))),
            ]),
            const SizedBox(height: 16),
            _section(_tr('support'), tc, [
              _item(Icons.help_outline_rounded, _tr('help_center'), tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen()))),
              _item(Icons.chat_bubble_outline_rounded, _tr('contact_support'), tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
              _item(Icons.bug_report_outlined, _tr('report_bug'), tc, onTap: () => showApexLoading(context, duration: const Duration(milliseconds: 800), label: 'Opening WhatsApp...')),
              _item(Icons.assessment_outlined, _tr('my_reports'), tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
            ]),
            const SizedBox(height: 16),
            _section(_tr('about'), tc, [
              _item(Icons.description_outlined, _tr('terms_of_service'), tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()))),
              _item(Icons.privacy_tip_outlined, _tr('privacy_policy'), tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()))),
              _item(Icons.info_outline_rounded, _tr('app_version'), tc),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _largeTextSwitchItem(ThemeColors tc, BuildContext context) {
    final textScale = TextScaleScope.of(context);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(Icons.text_fields_rounded, size: 22, color: tc.hint),
      title: Text(_tr('large_text'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tc.text)),
      subtitle: Text(
        textScale.isLargeText ? _tr('text_size_large') : _tr('text_size_default'),
        style: TextStyle(fontSize: 12, color: tc.hint),
      ),
      trailing: Switch(
        value: textScale.isLargeText,
        onChanged: (v) {
          textScale.toggleLargeText();
          _showToast(v ? _tr('large_text_enabled') : _tr('large_text_disabled'));
        },
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _darkModeSwitchItem(ThemeColors tc, bool isDark, ThemeProvider themeProvider) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(
        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        size: 22,
        color: isDark ? const Color(0xFFFBBF24) : tc.hint,
      ),
      title: Text(_tr('dark_mode'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tc.text)),
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          color: isDark ? AppColors.primary : tc.border,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black.withValues(alpha: 0.15))],
            ),
          ),
        ),
      ),
      onTap: () {
        themeProvider.toggleTheme();
        _showToast(isDark ? _tr('light_mode_enabled') : _tr('dark_mode_enabled'));
      },
    );
  }

  Widget _section(String title, ThemeColors tc, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tc.hint)),
            ),
          ...children,
        ],
      ),
    );
  }

  Widget _switchItem(IconData icon, String label, bool value, ThemeColors tc, ValueChanged<bool> onChanged) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, size: 22, color: tc.hint),
      title: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tc.text)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _languageItem(String label, String code, ThemeColors tc) {
    final selected = _selectedLang == code;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(label, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: tc.text)),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, size: 22, color: AppColors.primary)
          : null,
      onTap: () => _changeLanguage(code, label),
    );
  }

  Widget _item(IconData icon, String label, ThemeColors tc, {VoidCallback? onTap}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, size: 22, color: tc.hint),
      title: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tc.text)),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: tc.hint),
      onTap: onTap ?? () {
        _showToast('$label opened');
      },
    );
  }
}

class _SettingsToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  const _SettingsToast({required this.message, required this.onDismiss});

  @override
  State<_SettingsToast> createState() => _SettingsToastState();
}

class _SettingsToastState extends State<_SettingsToast> with SingleTickerProviderStateMixin {
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
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDismiss();
    });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 16;
    return Positioned(
      top: topPadding, left: 24, right: 24,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [BoxShadow(blurRadius: 16, color: AppColors.success.withValues(alpha: 0.35))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.message, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
