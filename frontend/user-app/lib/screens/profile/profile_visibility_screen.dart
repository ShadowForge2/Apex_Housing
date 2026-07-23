import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';

class ProfileVisibilityScreen extends StatefulWidget {
  const ProfileVisibilityScreen({super.key});

  @override
  State<ProfileVisibilityScreen> createState() => _ProfileVisibilityScreenState();
}

class _ProfileVisibilityScreenState extends State<ProfileVisibilityScreen> {
  bool _showOnline = true;
  bool _showActivity = true;
  bool _showListings = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showOnline = prefs.getBool('profile_show_online') ?? true;
        _showActivity = prefs.getBool('profile_show_activity') ?? true;
        _showListings = prefs.getBool('profile_show_listings') ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Profile Visibility'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 24, color: AppColors.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Control what other users can see about your activity on APEX Housing.',
                            style: TextStyle(fontSize: 13, color: tc.subtitle, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('Activity Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tc.text)),
                  const SizedBox(height: 14),
                  _toggleCard(
                    icon: Icons.circle,
                    iconColor: _showOnline ? AppColors.success : tc.hint,
                    title: 'Show Online Status',
                    subtitle: _showOnline ? 'Others can see when you\'re online' : 'Your online status is hidden',
                    value: _showOnline,
                    tc: tc,
                    onChanged: (v) {
                      setState(() => _showOnline = v);
                      _savePreference('profile_show_online', v);
                    },
                  ),
                  const SizedBox(height: 12),
                  _toggleCard(
                    icon: Icons.access_time_rounded,
                    iconColor: AppColors.warning,
                    title: 'Show Recent Activity',
                    subtitle: _showActivity ? 'Others can see your last active time' : 'Last active time is hidden',
                    value: _showActivity,
                    tc: tc,
                    onChanged: (v) {
                      setState(() => _showActivity = v);
                      _savePreference('profile_show_activity', v);
                    },
                  ),
                  const SizedBox(height: 28),
                  Text('Profile Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tc.text)),
                  const SizedBox(height: 14),
                  _toggleCard(
                    icon: Icons.home_work_outlined,
                    iconColor: AppColors.primary,
                    title: 'Show My Listings',
                    subtitle: _showListings ? 'Your listings are visible to tenants' : 'Listings are hidden from search',
                    value: _showListings,
                    tc: tc,
                    onChanged: (v) {
                      setState(() => _showListings = v);
                      _savePreference('profile_show_listings', v);
                    },
                  ),
                  const SizedBox(height: 28),
                  Text('What\'s Hidden', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tc.text)),
                  const SizedBox(height: 14),
                  _infoRow(Icons.lock_outline_rounded, 'Your exact location is never shared', tc),
                  const SizedBox(height: 12),
                  _infoRow(Icons.lock_outline_rounded, 'Phone number is only visible to confirmed tenants', tc),
                  const SizedBox(height: 12),
                  _infoRow(Icons.lock_outline_rounded, 'Email is never shown to other users', tc),
                ],
              ),
            ),
    );
  }

  Widget _toggleCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ThemeColors tc,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tc.text)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: tc.subtitle)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, ThemeColors tc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: tc.hint),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: tc.subtitle, height: 1.4))),
      ],
    );
  }
}
