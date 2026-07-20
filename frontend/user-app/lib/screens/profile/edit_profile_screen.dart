import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../services/user_service.dart';
import '../../services/token_storage.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();
  bool _loading = true;
  String? _profilePicture;
  String _initials = 'U';
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final email = await TokenStorage().getUserEmail();
      _emailController.text = email ?? '';
      final profile = await UserService().getMyProfile();
      _nameController.text = [profile.firstName, profile.lastName].where((e) => e != null && e.isNotEmpty).join(' ');
      _emailController.text = profile.email ?? email ?? '';
      _bioController.text = profile.bio ?? '';
      _phoneController.text = profile.phoneNumber ?? '';
      _profilePicture = profile.profilePicture;
      final name = _nameController.text.trim();
      final words = name.split(' ');
      _initials = words.length >= 2 ? '${words[0][0]}${words[1][0]}'.toUpperCase() : (name.isNotEmpty ? name[0].toUpperCase() : 'U');
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: ApexLoading())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildAvatar(),
                  const SizedBox(height: 32),
                  _buildField('Full Name', _nameController, Icons.person_outline_rounded),
                  const SizedBox(height: 18),
                  _buildField('Email', _emailController, Icons.email_outlined),
                  const SizedBox(height: 18),
                  _buildField('Phone', _phoneController, Icons.phone_outlined),
                  const SizedBox(height: 18),
                  _buildField('Location', _locationController, Icons.location_on_outlined),
                  const SizedBox(height: 18),
                  _buildField('Bio', _bioController, Icons.info_outline_rounded, maxLines: 3),
                  const SizedBox(height: 32),
                  AppButton(
                    text: 'Save Changes',
                    onPressed: _saveProfile,
                    icon: Icons.check_rounded,
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Future<void> _saveProfile() async {
    final nameParts = _nameController.text.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : null;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : null;

    showApexLoadingThen(context, () async {
      try {
        await UserService().updateProfile(
          firstName: firstName,
          lastName: lastName,
          bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
          phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }, label: 'Saving...');
  }

  Widget _buildAvatar() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: AppColors.primary,
          backgroundImage: _profilePicture != null && _profilePicture!.isNotEmpty
              ? NetworkImage(_profilePicture!)
              : null,
          child: _profilePicture == null || _profilePicture!.isEmpty
              ? Text(_initials, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700))
              : null,
        ),
        GestureDetector(
          onTap: _showPhotoOptions,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showPhotoOptions() {
    final tc = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: tc.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 18),
              Text('Change Profile Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tc.text)),
              const SizedBox(height: 20),
              _photoOption(
                icon: Icons.photo_library_outlined,
                label: 'Upload from Gallery',
                color: AppColors.primary,
                tc: tc,
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (picked != null) await _uploadPicture(picked.path);
                },
              ),
              const SizedBox(height: 8),
              _photoOption(
                icon: Icons.camera_alt_outlined,
                label: 'Take Photo',
                color: AppColors.success,
                tc: tc,
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (picked != null) await _uploadPicture(picked.path);
                },
              ),
              const SizedBox(height: 8),
              _photoOption(
                icon: Icons.delete_outline_rounded,
                label: 'Remove Photo',
                color: AppColors.error,
                tc: tc,
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await UserService().updateProfile(profilePicture: '');
                    if (mounted) setState(() => _profilePicture = null);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile picture removed'), backgroundColor: AppColors.success),
                      );
                    }
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to remove photo'), backgroundColor: AppColors.error),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoOption({
    required IconData icon,
    required String label,
    required Color color,
    required ThemeColors tc,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tc.text)),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadPicture(String filePath) async {
    showApexLoadingThen(context, () async {
      try {
        final url = await UserService().uploadProfilePicture(filePath);
        if (mounted) {
          setState(() => _profilePicture = url);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload photo: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }, label: 'Uploading...');
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    final tc = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.text)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: tc.surface,
            borderRadius: BorderRadius.circular(maxLines > 1 ? AppRadius.lg : AppRadius.pill),
            border: Border.all(color: tc.border),
          ),
          child: Row(
            crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 18, top: maxLines > 1 ? 16 : 0),
                child: Icon(icon, size: 20, color: tc.hint),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  ),
                  style: TextStyle(fontSize: 15, color: tc.text),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
