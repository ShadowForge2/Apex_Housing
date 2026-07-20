import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/loading_overlay.dart';
import '../messages/chat_detail_screen.dart';
import 'report_bug_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int _expandedFaq = -1;

  static const _whatsappNumber = '2250719570266';
  static const _whatsappMessage = 'Hello APEX Housing Support! I need assistance.';
  static const _telegramUrl = 'https://t.me/CPBloomFX';
  static const _email = 'support@apex-housing.online';
  static const _phone = 'tel:+2250719570266';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url'), backgroundColor: AppColors.error),
      );
    }
  }

  final _faqs = [
    {
      'q': 'How do I book a property?',
      'a': 'Browse properties on the Home or Map tab, tap on a listing, and press "Book Now". Follow the steps to select your move-in date and complete the escrow payment.',
    },
    {
      'q': 'How does escrow payment work?',
      'a': 'Your payment is held securely in escrow until the inspection is complete and you confirm move-in. If the property doesn\'t match the listing, you can raise a dispute and get a refund.',
    },
    {
      'q': 'How do I list my property as a landlord?',
      'a': 'Switch to Landlord mode from your Profile, go to My Listings, and tap "Add New". Fill in the property details, upload photos, and submit for verification.',
    },
    {
      'q': 'Can I cancel a booking?',
      'a': 'Yes. You can cancel a booking before move-in from the Bookings tab. A full refund will be processed to your original payment method within 3-5 business days.',
    },
    {
      'q': 'How do I verify my identity (KYC)?',
      'a': 'Go to Profile > KYC Verification. Upload a valid government-issued ID and take a selfie. Verification is usually completed within 24 hours.',
    },
    {
      'q': 'How do I report a maintenance issue?',
      'a': 'Go to your active booking, tap "Report Issue", describe the problem, and submit. Your landlord will be notified and you can track the status in the app.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildLiveChatBanner(tc),
            const SizedBox(height: 28),
            _buildSectionTitle('Contact Us', tc),
            const SizedBox(height: 14),
            _buildContactOptions(tc),
            const SizedBox(height: 28),
            _buildSectionTitle('Frequently Asked Questions', tc),
            const SizedBox(height: 14),
            _buildFaqList(tc),
            const SizedBox(height: 28),
            _buildSectionTitle('Other Ways to Reach Us', tc),
            const SizedBox(height: 14),
            _buildOtherContact(tc),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeColors tc) {
    return Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tc.text, letterSpacing: -0.3));
  }

  Widget _buildLiveChatBanner(ThemeColors tc) {
    return GestureDetector(
      onTap: () => showApexLoadingThen(
        context,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatDetailScreen(name: 'APEX Support'))),
        label: 'Connecting to agent...',
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [BoxShadow(blurRadius: 18, color: AppColors.primary.withValues(alpha: 0.3))],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start Live Chat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    'Chat with a support agent for instant help',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactOptions(ThemeColors tc) {
    return Column(
      children: [
        _contactCard(
          icon: Icons.chat_bubble_outline_rounded,
          iconBg: const Color(0xFF25D366),
          title: 'WhatsApp',
          subtitle: 'Chat with us on WhatsApp',
          trailing: 'Open',
          tc: tc,
          onTap: () => _launchUrl('https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent(_whatsappMessage)}'),
        ),
        const SizedBox(height: 12),
        _contactCard(
          icon: Icons.telegram_rounded,
          iconBg: const Color(0xFF0088CC),
          title: 'Telegram',
          subtitle: 'Message us on Telegram',
          trailing: 'Open',
          tc: tc,
          onTap: () => _launchUrl(_telegramUrl),
        ),
        const SizedBox(height: 12),
        _contactCard(
          icon: Icons.email_outlined,
          iconBg: AppColors.warning,
          title: 'Email',
          subtitle: _email,
          trailing: 'Send',
          tc: tc,
          onTap: () => _launchUrl('mailto:$_email?subject=Support Request'),
        ),
        const SizedBox(height: 12),
        _contactCard(
          icon: Icons.phone_outlined,
          iconBg: AppColors.primary,
          title: 'Phone',
          subtitle: '+234 800 APEX (2739)',
          trailing: 'Call',
          tc: tc,
          onTap: () => _launchUrl(_phone),
        ),
      ],
    );
  }

  Widget _contactCard({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String trailing,
    required ThemeColors tc,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                color: iconBg.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconBg, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tc.text)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: tc.hint)),
                ],
              ),
            ),
            Text(trailing, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqList(ThemeColors tc) {
    return Container(
      decoration: BoxDecoration(
        color: tc.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
      ),
      child: Column(
        children: List.generate(_faqs.length, (i) {
          final faq = _faqs[i];
          final expanded = _expandedFaq == i;
          return Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => _expandedFaq = expanded ? -1 : i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(faq['q']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.text)),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: tc.hint),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(faq['a']!, style: TextStyle(fontSize: 13, color: tc.subtitle, height: 1.5)),
                ),
                crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              if (i < _faqs.length - 1)
                Divider(height: 1, indent: 20, endIndent: 20, color: tc.border),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildOtherContact(ThemeColors tc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 18, color: tc.hint),
              const SizedBox(width: 10),
              Text('Support Hours', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.text)),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text('Monday - Friday: 8:00 AM - 8:00 PM\nSaturday: 9:00 AM - 5:00 PM\nSunday: Closed',
                style: TextStyle(fontSize: 13, color: tc.subtitle, height: 1.5)),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: tc.border),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.language_rounded, size: 18, color: tc.hint),
              const SizedBox(width: 10),
              Text('Website', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.text)),
            ],
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 28),
            child: Text('www.apex-housing.online', style: TextStyle(fontSize: 13, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
