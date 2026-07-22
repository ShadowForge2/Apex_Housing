import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_provider.dart';
import '../../theme/theme_colors.dart';
import '../../models/user_role.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../services/token_storage.dart';
import '../../services/location_service.dart';
import '../../services/api_client.dart';
import 'edit_profile_screen.dart';
import 'kyc_verification_screen.dart';
import 'signature_screen.dart';
import 'bank_account_screen.dart';
import 'onboarding_flow_screen.dart';
import 'sessions_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/terms_of_service_screen.dart';
import '../settings/reports_screen.dart';
import 'help_support_screen.dart';
import '../landlord/earnings_screen.dart';
import '../landlord/my_listings_screen.dart';
import '../landlord/tenants_screen.dart';
import '../landlord/analytics_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _darkModeAnimController;
  late Animation<double> _darkModeRotation;
  final Set<UserRole> _visitedRoles = {UserRole.tenant};

  UserProfile? _profile;
  VerificationStatus? _verificationStatus;
  String _fallbackEmail = '';
  String _location = '';
  bool _loading = true;

  void _showToast(String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ProfileToast(message: message, onDismiss: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  @override
  void initState() {
    super.initState();
    _darkModeAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _darkModeRotation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _darkModeAnimController, curve: Curves.easeInOutCubic),
    );
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final email = await TokenStorage().getUserEmail();
      _fallbackEmail = email ?? '';
      final results = await Future.wait([
        UserService().getMyProfile(),
        UserService().fetchVerificationStatus(),
      ]);
      if (mounted) setState(() {
        _profile = results[0] as UserProfile;
        _verificationStatus = results[1] as VerificationStatus;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ProfileScreen: Failed to load profile: $e');
      if (mounted) setState(() { _loading = false; });
    }
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final position = await AppLocationService.instance.getCurrentLocation();
      if (position != null) {
        final response = await Dio().get(
          'https://nominatim.openstreetmap.org/reverse',
          queryParameters: {
            'lat': position.latitude,
            'lon': position.longitude,
            'format': 'json',
          },
          options: Options(headers: {'User-Agent': 'APEX_Housing/1.0'}),
        );
        final data = response.data as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final city = address['city'] ?? address['town'] ?? address['village'] ?? address['state'] ?? '';
          final country = address['country'] ?? '';
          final locationStr = '$city, $country'.trim().replaceAll(RegExp(r'^,\s*'), '');
          if (mounted) setState(() => _location = locationStr);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_location', locationStr);
          await prefs.setDouble('user_latitude', position.latitude);
          await prefs.setDouble('user_longitude', position.longitude);
        }
      }
    } catch (e) {
      debugPrint('ProfileScreen: Failed to load location: $e');
      if (_location.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('user_location');
        if (saved != null && mounted) setState(() => _location = saved);
      }
    }
  }

  String get _displayName {
    if (_profile != null) {
      final parts = [_profile!.firstName, _profile!.lastName].where((e) => e != null && e.isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.join(' ');
    }
    return _fallbackEmail.isNotEmpty ? _fallbackEmail.split('@').first : 'User';
  }

  String get _displayEmail => _profile?.email ?? _fallbackEmail;
  String get _displayInitials {
    final name = _displayName;
    final words = name.split(' ');
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  @override
  void dispose() {
    _darkModeAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleProvider.of(context);
    final isLandlord = role.isLandlord;
    final tc = context.colors;
    final themeProvider = ThemeScope.of(context);
    final isDark = themeProvider.isDark;

    if (isDark && !_darkModeAnimController.isCompleted) {
      _darkModeAnimController.forward();
    } else if (!isDark && _darkModeAnimController.isCompleted) {
      _darkModeAnimController.reverse();
    }

    return Scaffold(
      backgroundColor: tc.background,
      body: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primary,
            backgroundImage: _profile?.profilePicture != null && _profile!.profilePicture!.isNotEmpty
                ? NetworkImage(_profile!.profilePicture!)
                : null,
            child: _profile?.profilePicture == null || _profile!.profilePicture!.isEmpty
                ? Text(_displayInitials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(height: 16),
          Text(_displayName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tc.text)),
          const SizedBox(height: 4),
          Text(_displayEmail, style: TextStyle(fontSize: 14, color: tc.subtitle)),
          const SizedBox(height: 4),
          if (_location.isNotEmpty) Text(_location, style: TextStyle(fontSize: 13, color: tc.hint)),
          // Phone number with edit icon
          if (_profile?.phoneNumber != null && _profile!.phoneNumber!.isNotEmpty)
            Row(
              children: [
                Expanded(child: Text(_profile!.phoneNumber!, style: TextStyle(fontSize: 13, color: tc.hint))),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _editField('Phone', _profile!.phoneNumber, (val) {}),
                ),
              ],
            ),
          // Bio with edit icon
          Row(
            children: [
              Expanded(child: Text(_profile?.bio?.isNotEmpty == true ? _profile!.bio! : 'No bio', style: TextStyle(fontSize: 13, color: tc.hint))),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _editField('Bio', _profile?.bio, (val) {}),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _badge(
                isLandlord ? 'Landlord' : 'Tenant',
                isLandlord ? AppColors.primary.withValues(alpha: 0.1) : AppColors.lightPurple,
                isLandlord ? AppColors.primaryDark : AppColors.primary,
              ),
              const SizedBox(width: 10),
              if (_verificationStatus != null && _verificationStatus!.isFullyActivated)
                _badge('Verified', AppColors.successLight, AppColors.success, icon: Icons.verified_rounded)
              else if (_verificationStatus != null)
                _badge('Unverified', AppColors.warningLight, AppColors.warning, icon: Icons.warning_amber_rounded)
              else
                _badge('Verified', AppColors.successLight, AppColors.success, icon: Icons.verified_rounded),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: tc.card,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fingerprint_rounded, size: 22, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tc.hint)),
                      const SizedBox(height: 2),
                      Text(_profile?.id ?? '---', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tc.text, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: _profile?.id ?? ''));
                    _showToast('User ID copied to clipboard');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _section('Account', tc, [
            _item(Icons.edit_outlined, 'Edit Profile', tc, onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
              _loadProfile();
            }),
            _item(Icons.badge_outlined, 'KYC Verification', tc, onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const KycVerificationScreen()));
              _loadProfile();
            }),
            _item(Icons.draw_rounded, 'Signature', tc, onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SignatureScreen()));
              _loadProfile();
            }),
            _item(Icons.account_balance_outlined, 'Bank Account', tc, onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const BankAccountScreen()));
              _loadProfile();
            }),
            if (_verificationStatus != null && !_verificationStatus!.isFullyActivated)
              _item(Icons.rocket_launch_rounded, 'Complete Setup', tc, onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingFlowScreen()));
                _loadProfile();
              }, highlight: true),
            _item(Icons.devices_outlined, 'Sessions', tc, onTap: () => _open(context, const SessionsScreen())),
            _item(
              Icons.swap_horiz_rounded,
              isLandlord ? 'Switch to Tenant' : 'Switch to Landlord',
              tc,
              onTap: () async {
                final targetRole = isLandlord ? UserRole.tenant : UserRole.landlord;
                final isFirstTime = !_visitedRoles.contains(targetRole);
                final roleStr = targetRole == UserRole.landlord ? 'LANDLORD' : 'TENANT';
                showApexLoading(context, duration: const Duration(seconds: 30), label: 'Switching profile...');
                try {
                  await ApiClient.instance.post('/users/switch-role', data: {'role': roleStr});
                  dismissApexLoading();
                  if (!mounted) return;
                  role.switchRole();
                  _visitedRoles.add(targetRole);
                  if (isFirstTime) {
                    if (targetRole == UserRole.landlord) {
                      _showToast('You are now in Landlord mode. You can now list properties!');
                    } else {
                      _showToast('You are now in Tenant mode. You can now book listings!');
                    }
                  } else {
                    _showToast('Switched to ${targetRole == UserRole.landlord ? "Landlord" : "Tenant"} profile');
                  }
                } catch (e) {
                  final msg = e.toString();
                  final isAlready = msg.contains('Already');
                  if (isAlready) {
                    dismissApexLoading();
                    if (!mounted) return;
                    role.switchRole();
                    _visitedRoles.add(targetRole);
                    _showToast('Role already set to ${targetRole == UserRole.landlord ? "Landlord" : "Tenant"}');
                    return;
                  }
                  final isServerError = msg.contains('Server error') || msg.contains('Internal server error') || msg.contains('500');
                  if (isServerError) {
                    try {
                      final profile = await UserService().getMyProfile();
                      final serverRole = profile.role?.toUpperCase();
                      final targetServerRole = targetRole == UserRole.landlord ? 'LANDLORD' : 'TENANT';
                      if (!mounted) { dismissApexLoading(); return; }
                      if (serverRole == targetServerRole) {
                        role.switchRole();
                        _visitedRoles.add(targetRole);
                        dismissApexLoading();
                        _showToast('Switched to ${targetRole == UserRole.landlord ? "Landlord" : "Tenant"} profile');
                        return;
                      }
                    } catch (_) {}
                  }
                  dismissApexLoading();
                  if (!mounted) return;
                  _showToast('Failed to switch role: $msg');
                }
              },
              highlight: true,
            ),
          ]),
          const SizedBox(height: 16),
          if (isLandlord) ...[
            _section('Landlord', tc, [
              _item(Icons.home_work_outlined, 'My Listings', tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyListingsScreen()))),
              _item(Icons.people_outline_rounded, 'Tenant Management', tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantsScreen()))),
              _item(Icons.payments_outlined, 'Earnings & Payouts', tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()))),
              _item(Icons.analytics_outlined, 'Analytics', tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()))),
            ]),
            const SizedBox(height: 16),
          ],
          _section('Settings', tc, [
            _item(Icons.notifications_outlined, 'Notifications', tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            _darkModeItem(tc, isDark, themeProvider),
            _item(Icons.language_rounded, 'Language', tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
            _item(Icons.help_outline_rounded, 'Help & Support', tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
            _item(Icons.description_outlined, 'Terms of Service', tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()))),
          ]),
          const SizedBox(height: 16),
          _section('Data', tc, [
            _item(Icons.assessment_outlined, 'My Reports', tc, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
          ]),
          const SizedBox(height: 16),
          _section('', tc, [
            _item(Icons.logout_rounded, 'Logout', tc, color: AppColors.error, onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                  title: Text('Logout', style: TextStyle(color: tc.text)),
                  content: Text('Are you sure you want to logout?', style: TextStyle(color: tc.subtitle)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: tc.subtitle)),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        showApexLoadingThen(context, () async {
                          final refreshToken = await TokenStorage().getRefreshToken();
                          await AuthService().logout(refreshToken: refreshToken ?? '');
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/splash', (route) => false);
                          }
                        });
                      },
                      child: const Text('Logout', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
            }),
          ]),
          const SizedBox(height: 48),
        ],
      ),
    ));
  }

  Future<void> _editField(String fieldName, String? currentValue, Function(String) onSave) async {
    final controller = TextEditingController(text: currentValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $fieldName'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $fieldName',
          ),
          maxLines: fieldName.toLowerCase() == 'bio' ? 3 : 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await UserService().updateProfile(
        bio: fieldName.toLowerCase() == 'bio' ? result : null,
        phoneNumber: fieldName.toLowerCase() == 'phone' ? result : null,
      );
      _loadProfile();
    }
  }

  void _open(BuildContext context, Widget screen) {
    showApexLoadingThen(context, () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    });
  }

  Widget _darkModeItem(ThemeColors tc, bool isDark, ThemeProvider themeProvider) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: AnimatedBuilder(
        animation: _darkModeRotation,
        builder: (_, child) {
          return Transform.rotate(
            angle: _darkModeRotation.value,
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 22,
              color: isDark ? const Color(0xFFFBBF24) : tc.hint,
            ),
          );
        },
      ),
      title: Text('Dark Mode', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tc.text)),
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
        _showToast(isDark ? 'Light mode enabled' : 'Dark mode enabled');
      },
    );
  }

  Widget _badge(String label, Color bg, Color fg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
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

  Widget _item(IconData icon, String label, ThemeColors tc, {Color? color, VoidCallback? onTap, bool highlight = false}) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, size: 22, color: highlight ? AppColors.primary : color ?? tc.hint),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
          color: highlight ? AppColors.primary : color ?? tc.text,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: highlight ? AppColors.primary : color ?? tc.hint),
      onTap: onTap ?? () {},
    );
  }
}

class _ProfileToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ProfileToast({required this.message, required this.onDismiss});

  @override
  State<_ProfileToast> createState() => _ProfileToastState();
}

class _ProfileToastState extends State<_ProfileToast> with SingleTickerProviderStateMixin {
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
                color: AppColors.success,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [BoxShadow(blurRadius: 16, color: AppColors.success.withValues(alpha: 0.35))],
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
