import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
            _section('1. Acceptance of Terms', [
              'By accessing or using the APEX Housing platform ("Service"), you agree to be bound by these Terms of Service. If you do not agree, do not use the Service.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('2. Eligibility', [
              'You must be at least 18 years of age to use this Service. By using the Service, you represent and warrant that you meet this requirement.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('3. User Accounts', [
              'You are responsible for maintaining the confidentiality of your account credentials. You agree to notify us immediately of any unauthorised use of your account.',
              'We reserve the right to suspend or terminate accounts that violate these terms.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('4. Platform Role', [
              'APEX Housing acts as an intermediary between tenants and landlords. We do not own, manage, or take possession of any property listed on the platform.',
              'All lease agreements are strictly between the tenant and landlord.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('5. Fees & Payments', [
              'A 5% service fee is added to the tenant\'s total. A 5% markdown is applied to the landlord\'s listing price.',
              'Payments are processed through our secure escrow system. Funds are released only after inspection and confirmation.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('6. Escrow & Inspections', [
              'All booking payments are held in escrow until the tenant completes a physical inspection of the property.',
              'The inspection window is 24 hours from booking confirmation. Failure to inspect within this period may result in automatic release of funds to the landlord.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('7. User Conduct', [
              'You agree not to misuse the platform, provide false information, engage in fraudulent activity, or harass other users.',
              'Listing properties that you do not own or have no authority to list is strictly prohibited.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('8. Privacy', [
              'Your use of the Service is also governed by our Privacy Policy, which describes how we collect, use, and protect your personal data.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('9. Dispute Resolution', [
              'Any disputes arising from the use of this platform should first be addressed through our in-app support system. We aim to resolve all issues within 48 hours.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('10. Limitation of Liability', [
              'APEX Housing shall not be held liable for any damages arising from the use of listed properties, disputes between tenants and landlords, or service interruptions.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('11. Modifications', [
              'We reserve the right to modify these terms at any time. Continued use of the Service after changes constitutes acceptance of the new terms.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            _section('12. Contact', [
              'For questions about these Terms, please contact us at support@apex-housing.online.',
            ], textColor: tc.text, subtitleColor: tc.subtitle),
            const SizedBox(height: 32),
            Text(
              'Last updated: July 16, 2026',
              style: TextStyle(fontSize: 12, color: tc.hint),
            ),
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
          Text(
            title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 8),
          ...paragraphs.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  p,
                  style: TextStyle(fontSize: 14, color: subtitleColor, height: 1.6),
                ),
              )),
        ],
      ),
    );
  }
}
