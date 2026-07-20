import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';

class ReportBugScreen extends StatelessWidget {
  const ReportBugScreen({super.key});

  static const _whatsappNumber = '2250719570266';
  static const _whatsappMessage = 'Hello APEX Support! I\'d like to report an issue.';

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent(_whatsappMessage)}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp. Please install WhatsApp.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Report a Bug'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 48),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bug_report_outlined, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            Text(
              'Report Any Issue',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tc.text),
            ),
            const SizedBox(height: 12),
            Text(
              'Found a bug, have a suggestion, or facing any issue? Report it directly to our support team via WhatsApp and we\'ll resolve it quickly.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: tc.subtitle, height: 1.6),
            ),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tc.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: tc.hint),
                      const SizedBox(width: 8),
                      Text('What to include', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tc.text)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _infoItem('Screenshots of the issue', tc),
                  const SizedBox(height: 4),
                  _infoItem('Steps to reproduce the problem', tc),
                  const SizedBox(height: 4),
                  _infoItem('Your device model and OS version', tc),
                  const SizedBox(height: 4),
                  _infoItem('Your user ID for quick identification', tc),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _openWhatsApp(context),
                icon: const Icon(Icons.chat_bubble_rounded, size: 22),
                label: const Text('Proceed to WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String text, ThemeColors tc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: tc.hint)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: tc.subtitle, height: 1.4))),
      ],
    );
  }
}
