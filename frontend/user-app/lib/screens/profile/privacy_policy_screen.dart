import 'package:flutter/material.dart';
import '../../theme/theme_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
            const SizedBox(height: 16),
            _section('1. Information We Collect', [
              'Account Information: Name, email address, phone number, and profile photo when you create an account.',
              'Identity Verification: Government-issued ID and selfie images submitted for KYC verification.',
              'Property Data: Listings, photos, pricing, and descriptions provided by landlords.',
              'Payment Information: Transaction history and payment method details processed through our secure payment gateway.',
              'Usage Data: App interactions, search queries, device information, and IP address for analytics and security.',
              'Communications: Messages sent through the in-app chat system between tenants, landlords, and support.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('2. How We Use Your Information', [
              'To provide, maintain, and improve the APEX Housing platform and its features.',
              'To process bookings, escrow payments, and facilitate landlord payouts.',
              'To verify user identities through our KYC process and prevent fraud.',
              'To send transactional emails, booking confirmations, and important account notifications.',
              'To communicate with you about support requests, updates, and promotional content (with your consent).',
              'To ensure platform security and detect suspicious or fraudulent activity.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('3. Information Sharing', [
              'With Landlords: When you book a property, your name and booking details are shared with the respective landlord.',
              'With Tenants: Landlord contact and property details are shared upon booking confirmation.',
              'Payment Processors: Transaction data is shared with our PCI-compliant payment partners to process escrow payments.',
              'Legal Requirements: We may disclose information when required by law, court order, or to protect the safety of our users.',
              'We do not sell your personal data to third parties for advertising or marketing purposes.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('4. Data Security', [
              'All data is encrypted in transit using TLS 1.3 and at rest using AES-256 encryption.',
              'Payment information is processed through PCI DSS Level 1 compliant systems and is never stored on our servers.',
              'KYC documents are stored in a secure, isolated environment with restricted access and automatic expiration.',
              'We implement role-based access controls, regular security audits, and automated threat detection.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('5. Data Retention', [
              'Account data is retained as long as your account is active. You may request deletion at any time.',
              'KYC documents are automatically deleted 90 days after verification or upon account closure.',
              'Transaction records are retained for 7 years as required by financial regulations.',
              'Chat messages are retained for 12 months and then permanently deleted.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('6. Your Rights', [
              'Access: Request a copy of all personal data we hold about you.',
              'Rectification: Request correction of inaccurate or incomplete data.',
              'Deletion: Request deletion of your account and associated personal data.',
              'Portability: Request your data in a structured, machine-readable format.',
              'Objection: Object to processing of your data for marketing or analytics purposes.',
              'To exercise these rights, contact our Data Protection Officer at support@apex-housing.online.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('7. Cookies & Tracking', [
              'We use essential cookies to maintain session state and remember your preferences.',
              'Analytics cookies help us understand how users interact with the app to improve the experience.',
              'We do not use third-party advertising trackers or sell browsing data to advertisers.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('8. Children\'s Privacy', [
              'APEX Housing is not intended for users under 18 years of age. We do not knowingly collect personal data from children. If we discover that a minor has provided personal data, we will promptly delete it.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('9. Changes to This Policy', [
              'We may update this Privacy Policy from time to time. Material changes will be communicated through in-app notifications and email. Continued use of the platform after changes constitutes acceptance.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('10. Contact Us', [
              'For privacy-related inquiries, contact our Data Protection Officer at support@apex-housing.online or reach out through the in-app Help & Support page.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            const SizedBox(height: 24),
            Text('Last updated: July 16, 2026', style: TextStyle(fontSize: 12, color: tc.hint)),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<String> paragraphs, {required Color textColor, required Color subtitleColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 8),
          ...paragraphs.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(p, style: TextStyle(fontSize: 14, color: subtitleColor, height: 1.6)),
              )),
        ],
      ),
    );
  }
}
