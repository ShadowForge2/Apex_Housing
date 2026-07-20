import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_colors.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color? color;

  const StatusBadge({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    final badgeColor = color ?? _getColor(text, tc);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: badgeColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getColor(String status, ThemeColors tc) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'active':
      case 'released':
      case 'satisfied':
        return AppColors.success;
      case 'pending':
      case 'pending payment':
      case 'pending_payment':
        return AppColors.warning;
      case 'cancelled':
      case 'rejected':
      case 'expired':
        return AppColors.error;
      case 'inspecting':
      case 'funds held':
      case 'funds_held':
        return AppColors.primary;
      default:
        return tc.subtitle;
    }
  }
}
