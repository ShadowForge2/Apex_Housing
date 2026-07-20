import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_colors.dart';
import '../services/user_service.dart';

class VerificationProgressBanner extends StatelessWidget {
  final VerificationStatus status;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const VerificationProgressBanner({
    super.key,
    required this.status,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (status.isFullyActivated) return const SizedBox.shrink();

    final tc = context.colors;
    final nextStepLabel = _getNextStepLabel();
    final stepColor = _getStepColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              stepColor.withValues(alpha: 0.12),
              stepColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: stepColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: stepColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getStepIcon(), color: stepColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Setup',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: tc.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextStepLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: tc.subtitle,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDismiss != null)
                  GestureDetector(
                    onTap: onDismiss,
                    child: Icon(Icons.close_rounded, size: 18, color: tc.hint),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: status.progressPercentage / 100,
                      backgroundColor: stepColor.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(stepColor),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${status.stepsCompleted}/${status.totalSteps}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: stepColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _stepDot('KYC', status.kycVerified, tc),
                _stepLine(status.kycVerified),
                _stepDot('Signature', status.hasSignature, tc),
                _stepLine(status.hasSignature),
                _stepDot('Bank', status.hasBankAccount, tc),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: stepColor,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'Complete Setup',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNextStepLabel() {
    switch (status.nextStep) {
      case 'kyc':
        return 'Upload your ID to verify your identity';
      case 'signature':
        return 'Draw your signature to continue';
      case 'bank_account':
        return 'Add a bank account for payouts';
      default:
        return 'Complete setup to unlock all features';
    }
  }

  IconData _getStepIcon() {
    switch (status.nextStep) {
      case 'kyc':
        return Icons.badge_outlined;
      case 'signature':
        return Icons.draw_rounded;
      case 'bank_account':
        return Icons.account_balance_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  Color _getStepColor() {
    switch (status.nextStep) {
      case 'kyc':
        return AppColors.warning;
      case 'signature':
        return AppColors.primary;
      case 'bank_account':
        return const Color(0xFF3B82F6);
      default:
        return AppColors.success;
    }
  }

  Widget _stepDot(String label, bool completed, ThemeColors tc) {
    final color = completed ? AppColors.success : AppColors.hint;
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: completed ? AppColors.success : tc.hint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLine(bool completed) {
    return Expanded(
      child: Container(
        height: 1.5,
        color: completed ? AppColors.success : AppColors.border,
      ),
    );
  }
}
