import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/app_button.dart';
import '../../services/user_service.dart';
import 'signature_screen.dart';

class KycVerificationScreen extends StatefulWidget {
  const KycVerificationScreen({super.key});

  @override
  State<KycVerificationScreen> createState() => _KycVerificationScreenState();
}

class _KycVerificationScreenState extends State<KycVerificationScreen> {
  int _selectedDocType = 0;
  final _docTypes = ['National ID (NIN)', 'International Passport', "Driver's License", 'Voter\'s Card'];
  String _status = 'not_started';
  bool _isLoadingStatus = true;
  bool _isSubmitting = false;
  String? _error;
  File? _documentFile;
  File? _selfieFile;
  final _userService = UserService();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  Future<void> _loadKycStatus() async {
    try {
      final kyc = await _userService.getKycStatus();
      if (mounted) {
        setState(() {
          _status = kyc.status ?? 'not_started';
          _isLoadingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Future<void> _pickDocument(bool isFront) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _documentFile = File(picked.path));
    }
  }

  Future<void> _pickSelfie() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    if (picked != null) {
      setState(() => _selfieFile = File(picked.path));
    }
  }

  Future<void> _submitKyc() async {
    if (_documentFile == null || _selfieFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both document and selfie')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final docTypeMap = {
        0: 'nin',
        1: 'passport',
        2: 'drivers_license',
        3: 'voters_card',
      };

      await _userService.submitKyc(
        documentType: docTypeMap[_selectedDocType] ?? 'nin',
        file: _documentFile!,
        selfie: _selfieFile!,
      );

      if (mounted) {
        setState(() {
          _status = 'pending';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('KYC Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingStatus
          ? const Center(child: ApexLoading())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildStatusBanner(),
                  if ((_status == 'approved' || _status == 'verified') && mounted) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const SignatureScreen(isPostSignup: true),
                            ),
                          );
                        },
                        icon: const Icon(Icons.draw, size: 18),
                        label: const Text('Continue to Signature', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
                    ),
                  ],
                  const SizedBox(height: 28),
                  if (_status == 'not_started') ...[
                    _buildStepIndicator(1, 'Choose ID Type', true),
                    const SizedBox(height: 16),
                    _buildDocTypeSelector(),
                    const SizedBox(height: 28),
                    _buildStepIndicator(2, 'Upload Document', _documentFile != null),
                    const SizedBox(height: 16),
                    _buildFrontUpload(),
                    const SizedBox(height: 14),
                    _buildBackUpload(),
                    const SizedBox(height: 28),
                    _buildStepIndicator(3, 'Selfie Verification', _selfieFile != null),
                    const SizedBox(height: 16),
                    _buildSelfiePlaceholder(),
                    const SizedBox(height: 32),
                    AppButton(
                      text: _isSubmitting ? 'Submitting...' : 'Submit for Verification',
                      onPressed: _isSubmitting ? null : _submitKyc,
                      icon: Icons.verified_user_outlined,
                    ),
                  ] else if (_status == 'pending') ...[
                    _buildPendingState(),
                  ] else ...[
                    _buildVerifiedState(),
                  ],
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBanner() {
    final tc = context.colors;
    Color bg, fg;
    IconData icon;
    String title, subtitle;
    switch (_status) {
      case 'pending':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        icon = Icons.hourglass_top_rounded;
        title = 'Verification Pending';
        subtitle = 'Your documents are being reviewed. This usually takes 24-48 hours.';
        break;
      case 'verified':
        bg = AppColors.successLight;
        fg = AppColors.success;
        icon = Icons.verified_rounded;
        title = 'Verification Complete';
        subtitle = 'Your identity has been verified successfully.';
        break;
      case 'approved':
        bg = AppColors.successLight;
        fg = AppColors.success;
        icon = Icons.verified_rounded;
        title = 'Verification Complete';
        subtitle = 'Your identity has been verified successfully.';
        break;
      default:
        bg = tc.surfaceVariant;
        fg = AppColors.primary;
        icon = Icons.shield_outlined;
        title = 'Verify Your Identity';
        subtitle = 'Complete KYC to unlock all platform features and build trust.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: fg, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool active) {
    final tc = context.colors;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : tc.surface,
            shape: BoxShape.circle,
            border: active ? null : Border.all(color: tc.border),
          ),
          alignment: Alignment.center,
          child: Text('$step', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : tc.hint)),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: active ? tc.text : tc.hint)),
      ],
    );
  }

  Widget _buildDocTypeSelector() {
    final tc = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: List.generate(_docTypes.length, (i) {
          final selected = _selectedDocType == i;
          final last = i == _docTypes.length - 1;
          return GestureDetector(
            onTap: () => setState(() => _selectedDocType = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: last ? null : Border(bottom: BorderSide(color: tc.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.primary : Colors.transparent,
                      border: Border.all(color: selected ? AppColors.primary : tc.border, width: 2),
                    ),
                    child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 14),
                  Text(_docTypes[i], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: selected ? tc.text : tc.subtitle)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFrontUpload() {
    return _buildUploadBox('Front of Document', 'Take a clear photo of the front', _documentFile, () => _pickDocument(true));
  }

  Widget _buildBackUpload() {
    return _buildUploadBox('Back of Document', 'Take a clear photo of the back', null, null);
  }

  Widget _buildUploadBox(String title, String subtitle, File? file, VoidCallback? onPick) {
    final tc = context.colors;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: file != null ? AppColors.success : tc.border,
            width: 2,
            style: BorderStyle.solid,
          ),
          boxShadow: AppShadow.soft,
        ),
        child: file != null
            ? Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(file, height: 120, width: double.infinity, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text('Document selected', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
                    ],
                  ),
                ],
              )
            : Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.file_upload_outlined, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tc.text)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: tc.hint)),
                ],
              ),
      ),
    );
  }

  Widget _buildSelfiePlaceholder() {
    final tc = context.colors;
    return GestureDetector(
      onTap: _pickSelfie,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: _selfieFile != null ? AppColors.success : tc.border,
            width: 2,
            style: BorderStyle.solid,
          ),
          boxShadow: AppShadow.soft,
        ),
        child: _selfieFile != null
            ? Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selfieFile!, height: 120, width: double.infinity, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 18, color: AppColors.success),
                      SizedBox(width: 6),
                      Text('Selfie captured', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
                    ],
                  ),
                ],
              )
            : Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.face_rounded, color: AppColors.success, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text('Take a Selfie', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tc.text)),
                  const SizedBox(height: 4),
                  Text('We\'ll compare it with your ID photo', style: TextStyle(fontSize: 13, color: tc.hint)),
                ],
              ),
      ),
    );
  }

  Widget _buildPendingState() {
    final tc = context.colors;
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: AppColors.warningLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.hourglass_top_rounded, size: 40, color: AppColors.warning),
        ),
        const SizedBox(height: 24),
        Text('Under Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tc.text)),
        const SizedBox(height: 10),
        Text(
          'Your documents are being reviewed by our team. You\'ll receive a notification once the verification is complete.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: tc.subtitle, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: const Text('Estimated time: 24-48 hours', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning)),
        ),
      ],
    );
  }

  Widget _buildVerifiedState() {
    final tc = context.colors;
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: AppColors.successLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified_rounded, size: 40, color: AppColors.success),
        ),
        const SizedBox(height: 24),
        Text('Identity Verified', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tc.text)),
        const SizedBox(height: 10),
        Text(
          'Your identity has been verified. You now have full access to all platform features.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: tc.subtitle, height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 18, color: AppColors.success),
              SizedBox(width: 8),
              Text('Verified Identity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success)),
            ],
          ),
        ),
      ],
    );
  }
}
