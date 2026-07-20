import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/theme_colors.dart';
import '../models/models.dart';
import 'status_badge.dart';

class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onTap;

  const BookingCard({super.key, required this.booking, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tc.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.network(
                    booking.propertyImage,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: tc.surfaceVariant,
                      child: Icon(Icons.home, color: tc.hint),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.reference,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tc.hint, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.propertyTitle,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusBadge(text: booking.status),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _meta(Icons.calendar_today_rounded, booking.moveInDate, tc),
                const SizedBox(width: 16),
                _meta(Icons.payments_outlined, booking.amountFormatted, tc),
                const Spacer(),
                StatusBadge(text: booking.escrowStatus.replaceAll('_', ' ')),
              ],
            ),
            if (booking.inspectionHoursLeft != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Text(
                      'Inspection: ${booking.inspectionHoursLeft}h remaining',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, ThemeColors tc) {
    return Row(
      children: [
        Icon(icon, size: 14, color: tc.hint),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: tc.subtitle, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
