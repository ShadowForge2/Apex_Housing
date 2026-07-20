import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../services/user_service.dart';
import 'kyc_verification_screen.dart';
import 'signature_screen.dart';
import 'bank_account_screen.dart';

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final _userService = UserService();
  VerificationStatus? _status;
  bool _isLoading = true;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _userService.fetchVerificationStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _isLoading = false;
        });
        if (status.isFullyActivated) {
          Navigator.pop(context, true);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToStep(String step) async {
    if (_navigating) return;
    setState(() => _navigating = true);

    Widget screen;
    switch (step) {
      case 'kyc':
        screen = const KycVerificationScreen();
        break;
      case 'signature':
        screen = const SignatureScreen();
        break;
      case 'bank_account':
        screen = const BankAccountScreen();
        break;
      default:
        return;
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    setState(() => _navigating = false);
    _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tc.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: ApexLoading())
          : _status == null
              ? _buildError(tc)
              : _buildContent(tc),
    );
  }

  Widget _buildError(ThemeColors tc) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Failed to load verification status', style: TextStyle(fontSize: 16, color: tc.text)),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadStatus, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeColors tc) {
    final status = _status!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Complete Your Setup',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: tc.text),
          ),
          const SizedBox(height: 8),
          Text(
            'Verify your identity to unlock all APEX Housing features including bookings, messaging, and payments.',
            style: TextStyle(fontSize: 14, color: tc.subtitle, height: 1.5),
          ),
          const SizedBox(height: 28),
          _buildProgressBar(status, tc),
          const SizedBox(height: 32),
          _buildStepCard(
            step: 1,
            title: 'Identity Verification',
            subtitle: 'Upload a valid government-issued ID',
            isCompleted: status.kycVerified,
            isCurrent: status.nextStep == 'kyc',
            icon: Icons.badge_outlined,
            color: AppColors.warning,
            tc: tc,
            onTap: () => _navigateToStep('kyc'),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: 2,
            title: 'Digital Signature',
            subtitle: 'Draw your signature for agreements',
            isCompleted: status.hasSignature,
            isCurrent: status.nextStep == 'signature',
            icon: Icons.draw_rounded,
            color: AppColors.primary,
            tc: tc,
            onTap: () => _navigateToStep('signature'),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: 3,
            title: 'Bank Account',
            subtitle: 'Add a bank account for payouts',
            isCompleted: status.hasBankAccount,
            isCurrent: status.nextStep == 'bank_account',
            icon: Icons.account_balance_outlined,
            color: const Color(0xFF3B82F6),
            tc: tc,
            onTap: () => _navigateToStep('bank_account'),
          ),
          const SizedBox(height: 40),
          if (status.isFullyActivated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Set!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.success),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your account is fully activated. You can now book, message, and transact.',
                          style: TextStyle(fontSize: 13, color: AppColors.success.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProgressBar(VerificationStatus status, ThemeColors tc) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              '${status.stepsCompleted} of ${status.totalSteps} steps completed',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc.subtitle),
            ),
            const Spacer(),
            Text(
              '${status.progressPercentage}%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: status.progressPercentage / 100,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isCurrent,
    required IconData icon,
    required Color color,
    required ThemeColors tc,
    required VoidCallback onTap,
  }) {
    final effectiveColor = isCompleted ? AppColors.success : color;
    final borderColor = isCurrent
        ? effectiveColor.withValues(alpha: 0.5)
        : isCompleted
            ? AppColors.success.withValues(alpha: 0.3)
            : tc.border;

    return GestureDetector(
      onTap: isCompleted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: borderColor,
            width: isCurrent ? 1.5 : 1,
          ),
          boxShadow: isCurrent
              ? [BoxShadow(blurRadius: 12, color: effectiveColor.withValues(alpha: 0.12))]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: isCompleted
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24)
                  : Icon(icon, color: effectiveColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Step $step',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: effectiveColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(width: 6),
                        Text(
                          'DONE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tc.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: tc.subtitle),
                  ),
                ],
              ),
            ),
            if (!isCompleted)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isCurrent ? effectiveColor : tc.hint,
              ),
          ],
        ),
      ),
    );
  }
}
