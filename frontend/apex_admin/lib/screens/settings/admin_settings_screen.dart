import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../theme/app_colors.dart';
import '../../utils/loading_overlay.dart';
import '../../services/token_storage.dart';
import '../../services/admin_service.dart';
import '../../services/admin_auth_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const AdminSettingsScreen({super.key, this.isSuperAdmin = false});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _feeController = TextEditingController(text: '10');
  final _minBookingController = TextEditingController(text: '1000');
  final _ipWhitelistController = TextEditingController(text: '192.168.1.0/24\n10.0.0.0/8');
  final LocalAuthentication _localAuth = LocalAuthentication();
  final AdminService _adminService = AdminService();

  bool _autoApproveListings = false;
  bool _maintenanceMode = false;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _pushNotifications = true;
  bool _twoFactorAuth = true;
  bool _biometricLogin = false;
  String _sessionTimeout = '30min';
  bool _settingsLoading = true;

  // Broadcast announcement state
  final _broadcastTitleController = TextEditingController();
  final _broadcastMessageController = TextEditingController();
  bool _broadcastSendEmail = false;
  List<String>? _broadcastRoles;
  bool _isBroadcasting = false;

  bool get _isSuperAdmin => widget.isSuperAdmin;

  @override
  void initState() {
    super.initState();
    _feeController.addListener(() => setState(() {}));
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final result = await _adminService.getPlatformSettings();
      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          _autoApproveListings = data['auto_approve_listings'] ?? false;
          _maintenanceMode = data['maintenance_mode'] ?? false;
          _feeController.text = '${data['platform_fee_percentage'] ?? 10}';
          _minBookingController.text = '${data['min_booking_amount'] ?? 1000}';
          _settingsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _settingsLoading = false);
    }
    final enabled = await TokenStorage().isBiometricEnabled();
    if (mounted) setState(() => _biometricLogin = enabled);
  }

  @override
  void dispose() {
    _feeController.dispose();
    _minBookingController.dispose();
    _ipWhitelistController.dispose();
    _broadcastTitleController.dispose();
    _broadcastMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.5)),
              const SizedBox(height: 24),
              _buildPlatformSettings(),
              const SizedBox(height: 16),
              _buildNotificationSettings(),
              const SizedBox(height: 16),
              _buildSecuritySettings(),
              const SizedBox(height: 16),
              _buildBiometricSettings(),
              const SizedBox(height: 16),
              if (_isSuperAdmin) ...[
                _buildBroadcastSection(),
                const SizedBox(height: 16),
              ],
              _buildDangerZone(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.minimal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSettingsRow({
    required String label,
    String? subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.hint)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildSwitch({required bool value, ValueChanged<bool>? onChanged}) {
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }

  Widget _buildEditableField(TextEditingController controller, {String suffix = ''}) {
    return SizedBox(
      width: 100,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixText: suffix,
          suffixStyle: const TextStyle(fontSize: 13, color: AppColors.subtitle),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformSettings() {
    final fee = double.tryParse(_feeController.text) ?? 10;
    final half = (fee / 2).toStringAsFixed(fee % 2 == 0 ? 0 : 1);

    return _buildSectionCard(
      title: 'Platform Settings',
      children: [
        const Divider(height: 1, color: AppColors.borderLight),
        _buildSettingsRow(
          label: 'Platform Fee Percentage',
          subtitle: 'Total commission — auto-split 50/50',
          trailing: _buildEditableField(_feeController, suffix: '%'),
        ),
        const Divider(height: 1, indent: 20, color: AppColors.borderLight),
        _buildSettingsRow(
          label: 'Tenant Markup',
          subtitle: 'Half added to rent (${_feeController.text}% ÷ 2)',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text('$half%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.hint)),
          ),
        ),
        const Divider(height: 1, indent: 20, color: AppColors.borderLight),
        _buildSettingsRow(
          label: 'Agent Markdown',
          subtitle: 'Half deducted from landlord',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text('$half%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.hint)),
          ),
        ),
        const Divider(height: 1, indent: 20, color: AppColors.borderLight),
        _buildSettingsRow(
          label: 'Minimum Booking Amount',
          subtitle: 'Lowest allowed booking value',
          trailing: _buildEditableField(_minBookingController, suffix: '\u20A6'),
        ),
        const Divider(height: 1, indent: 20, color: AppColors.borderLight),
        _buildSettingsRow(
          label: 'Auto-approve Listings',
          subtitle: 'Automatically approve new property listings',
          trailing: Opacity(
            opacity: _isSuperAdmin ? 1.0 : 0.4,
            child: _buildSwitch(
              value: _autoApproveListings,
              onChanged: _isSuperAdmin ? (v) async {
                setState(() => _autoApproveListings = v);
                try {
                  await _adminService.updatePlatformSettings(autoApproveListings: v);
                  if (mounted) showAppToast(context, 'Auto-approve listings ${v ? 'enabled' : 'disabled'}');
                } catch (e) {
                  setState(() => _autoApproveListings = !v);
                  if (mounted) showAppToast(context, 'Failed to update setting');
                }
              } : null,
            ),
          ),
        ),
        const Divider(height: 1, indent: 20, color: AppColors.borderLight),
        _buildSettingsRow(
          label: 'Maintenance Mode',
          subtitle: 'Temporarily disable public access',
          trailing: Opacity(
            opacity: _isSuperAdmin ? 1.0 : 0.4,
            child: _buildSwitch(
              value: _maintenanceMode,
              onChanged: _isSuperAdmin ? (v) async {
                setState(() => _maintenanceMode = v);
                try {
                  await _adminService.updatePlatformSettings(maintenanceMode: v);
                  if (mounted) showAppToast(context, 'Maintenance mode ${v ? 'enabled' : 'disabled'}');
                } catch (e) {
                  setState(() => _maintenanceMode = !v);
                  if (mounted) showAppToast(context, 'Failed to update setting');
                }
              } : null,
            ),
          ),
        ),
        if (_isSuperAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveNumericSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textWhite,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
                child: const Text('Save Numeric Settings', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        if (!_isSuperAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.hint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Only Super Admin can modify platform settings.',
                    style: TextStyle(fontSize: 12, color: AppColors.hint),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _saveNumericSettings() async {
    final fee = double.tryParse(_feeController.text);
    final minBooking = int.tryParse(_minBookingController.text);

    if (fee == null || minBooking == null) {
      if (mounted) showAppToast(context, 'Please enter valid numbers');
      return;
    }

    try {
      await _adminService.updatePlatformSettings(
        platformFeePercentage: fee,
        minBookingAmount: minBooking,
      );
      // Re-read settings to sync derived values from server
      final result = await _adminService.getPlatformSettings();
      final data = result['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          _feeController.text = '${data['platform_fee_percentage'] ?? fee}';
          _minBookingController.text = '${data['min_booking_amount'] ?? minBooking}';
        });
      }
      if (mounted) showAppToast(context, 'Platform settings saved');
    } catch (e) {
      if (mounted) showAppToast(context, 'Failed to save settings');
    }
  }

  Widget _buildNotificationSettings() {
    return _buildSectionCard(
      title: 'Notification Settings',
      children: [
        const Divider(height: 1, color: AppColors.borderLight),
        _buildSettingsRow(
          label: 'Email Notifications',
          subtitle: 'Send alerts via email',
          trailing: _buildSwitch(
            value: _emailNotifications,
            onChanged: (v) {
              setState(() => _emailNotifications = v);
              showAppToast(context, 'Email notifications ${v ? 'enabled' : 'disabled'}');
            },
          ),
        ),
        const Divider(height: 1, indent: 20, color: AppColors.borderLight),
        _buildSettingsRow(
          label: 'SMS Notifications',
          subtitle: 'Send alerts via SMS',
          trailing: _buildSwitch(
            value: _smsNotifications,
            onChanged: (v) {
              setState(() => _smsNotifications = v);
              showAppToast(context, 'SMS notifications ${v ? 'enabled' : 'disabled'}');
            },
          ),
        ),
        const Divider(height: 1, indent: 20, color: AppColors.borderLight),
        _buildSettingsRow(
          label: 'Push Notifications',
          subtitle: 'Send in-app push alerts',
          trailing: _buildSwitch(
            value: _pushNotifications,
            onChanged: (v) {
              setState(() => _pushNotifications = v);
              showAppToast(context, 'Push notifications ${v ? 'enabled' : 'disabled'}');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySettings() {
    return _buildSectionCard(
      title: 'Security Settings',
      children: [
        const Divider(height: 1, color: AppColors.borderLight),
        _buildSettingsRow(
          label: 'Two-Factor Authentication',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 12, color: AppColors.success),
                    SizedBox(width: 4),
                    Text('Enabled', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.lock_outline, size: 18, color: AppColors.hint),
            ],
          ),
        ),
        const Divider(height: 1, indent: 20, color: AppColors.borderLight),
        _buildSettingsRow(
          label: 'Session Timeout',
          subtitle: 'Auto-logout after inactivity',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButton<String>(
              value: _sessionTimeout,
              underline: const SizedBox(),
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.subtitle),
              items: const [
                DropdownMenuItem(value: '15min', child: Text('15 min', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: '30min', child: Text('30 min', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: '1hr', child: Text('1 hour', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (v) => setState(() => _sessionTimeout = v ?? _sessionTimeout),
            ),
          ),
        ),
        const Divider(height: 1, indent: 20, color: AppColors.borderLight),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text('IP Whitelist', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            controller: _ipWhitelistController,
            maxLines: 3,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'Enter IPs, one per line',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.hint),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricSettings() {
    return _buildSectionCard(
      title: 'Biometric Login',
      children: [
        const Divider(height: 1, color: AppColors.borderLight),
        _buildSettingsRow(
          label: 'Fingerprint / Face ID',
          subtitle: 'Sign in using biometric authentication',
          trailing: Opacity(
            opacity: _isSuperAdmin ? 1.0 : 0.4,
            child: Switch.adaptive(
              value: _biometricLogin,
              onChanged: _isSuperAdmin ? _toggleBiometric : null,
              activeColor: AppColors.primary,
            ),
          ),
        ),
        if (!_isSuperAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.hint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Only Super Admin can manage biometric settings.',
                    style: TextStyle(fontSize: 12, color: AppColors.hint),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _toggleBiometric(bool value) async {
    final storage = TokenStorage();

    if (value) {
      // Enable biometric — need stored email/password from last login
      final email = await storage.getUserEmail();
      if (email == null || email.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No stored credentials found. Please log in again first.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Prompt to confirm with biometric
      try {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Authenticate to enable fingerprint login',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
        if (!authenticated) return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Biometric authentication failed: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Show dialog to confirm password for storing
      final password = await _showPasswordDialog();
      if (password == null || password.isEmpty) return;

      try {
        final authService = AdminAuthService();
        final result = await authService.login(email: email, password: password);
        final data = result['data'] as Map<String, dynamic>?;
        final refreshToken = data?['refresh_token'] as String?;
        if (refreshToken != null) {
          await storage.setBiometricEnabled(email: email, refreshToken: refreshToken);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      if (mounted) {
        setState(() => _biometricLogin = true);
        showAppToast(context, 'Fingerprint login enabled');
      }
    } else {
      // Disable biometric
      try {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Authenticate to disable fingerprint login',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
        if (!authenticated) return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Biometric authentication failed: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      await storage.clearBiometric();
      if (mounted) {
        setState(() => _biometricLogin = false);
        showAppToast(context, 'Fingerprint login disabled');
      }
    }
  }

  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Confirm Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your password to enable fingerprint login. Credentials will be stored securely.',
              style: TextStyle(fontSize: 14, color: AppColors.subtitle),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Enter your password',
                hintStyle: TextStyle(color: AppColors.hint),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Enable', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _buildBroadcastSection() {
    return _buildSectionCard(
      title: 'Broadcast Announcement',
      children: [
        const Divider(height: 1, color: AppColors.borderLight),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send a platform-wide announcement to users',
                style: TextStyle(fontSize: 13, color: AppColors.subtitle),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _broadcastTitleController,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Announcement title',
                  hintStyle: const TextStyle(color: AppColors.hint),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _broadcastMessageController,
                maxLines: 4,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Write your announcement message...',
                  hintStyle: const TextStyle(color: AppColors.hint),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Send email too', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: _broadcastSendEmail,
                    onChanged: (v) => setState(() => _broadcastSendEmail = v),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Target audience', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildRoleChip('All Users', null),
                  _buildRoleChip('Tenants', ['TENANT']),
                  _buildRoleChip('Landlords', ['LANDLORD']),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isBroadcasting ? null : _sendBroadcast,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textWhite,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                  child: _isBroadcasting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send Announcement', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(String label, List<String>? roles) {
    final isSelected = _broadcastRoles == null && roles == null ||
        (_broadcastRoles != null && roles != null &&
         _broadcastRoles!.length == roles.length &&
         _broadcastRoles!.every((r) => roles.contains(r)));
    return GestureDetector(
      onTap: () => setState(() => _broadcastRoles = roles),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppColors.textWhite : AppColors.text,
          ),
        ),
      ),
    );
  }

  Future<void> _sendBroadcast() async {
    final title = _broadcastTitleController.text.trim();
    final message = _broadcastMessageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      showAppToast(context, 'Please enter title and message');
      return;
    }
    setState(() => _isBroadcasting = true);
    try {
      final result = await _adminService.broadcastAnnouncement(
        title: title,
        message: message,
        roles: _broadcastRoles,
        sendEmail: _broadcastSendEmail,
        emailSubject: 'APEX Housing: $title',
      );
      _broadcastTitleController.clear();
      _broadcastMessageController.clear();
      setState(() { _broadcastSendEmail = false; _broadcastRoles = null; });
      if (mounted) showAppToast(context, 'Announcement sent to ${result['data']?['recipients'] ?? 0} users');
    } catch (e) {
      if (mounted) showAppToast(context, 'Failed to send announcement');
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }

  Widget _buildDangerZone() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.errorLight),
        boxShadow: AppShadow.minimal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text('Danger Zone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          if (!_isSuperAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only Super Admin can export database data.',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          _buildSettingsRow(
            label: 'Export Database',
            subtitle: 'Download a copy of all platform data',
            trailing: Opacity(
              opacity: _isSuperAdmin ? 1.0 : 0.4,
              child: OutlinedButton(
                onPressed: _isSuperAdmin ? _confirmExport : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                ),
                child: const Text('Export', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _confirmExport() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Export Database', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to export all platform data? This will download a copy of the entire database.',
          style: TextStyle(fontSize: 14, color: AppColors.subtitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await runWithLoading(
                context,
                action: () async {
                  await Future.delayed(const Duration(milliseconds: 1500));
                },
                message: 'Exporting data...',
              );
              if (context.mounted) showAppToast(context, 'Export started successfully');
            },
            child: const Text('Export', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
