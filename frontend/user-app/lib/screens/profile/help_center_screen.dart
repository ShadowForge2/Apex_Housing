import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  int _expandedFaq = -1;

  final _categories = [
    {
      'title': 'Getting Started',
      'faqs': [
        {
          'q': 'How do I create an account?',
          'a': 'Download the APEX Housing app and tap "Get Started". Enter your email, create a password, and verify your account via the OTP sent to your email. You can then complete your profile and start browsing properties.',
        },
        {
          'q': 'How do I switch between Tenant and Landlord modes?',
          'a': 'Go to your Profile tab and tap "Switch to Landlord" or "Switch to Tenant". Your data, bookings, and listings are tied to your account so you can switch freely at any time.',
        },
        {
          'q': 'How do I complete my KYC verification?',
          'a': 'Navigate to Profile > KYC Verification. Upload a valid government-issued ID (NIN, International Passport, Driver\'s License, or Voter\'s Card) and take a selfie. Verification is typically completed within 24 hours.',
        },
      ],
    },
    {
      'title': 'Searching & Booking',
      'faqs': [
        {
          'q': 'How do I search for a property?',
          'a': 'Use the Home tab to browse featured listings or the Map tab to explore properties by location. You can filter by price range, property type (apartment, house, studio), and number of bedrooms.',
        },
        {
          'q': 'How does the booking process work?',
          'a': '1. Find a property you like and tap "Book Now"\n2. Select your move-in date\n3. Pay the total amount (rent + security deposit + service fee) via escrow\n4. Schedule and complete your inspection within 24 hours\n5. Confirm move-in to release payment to landlord',
        },
        {
          'q': 'What is the escrow system?',
          'a': 'Escrow is a secure payment holding system. When you book a property, your payment is held by APEX Housing and only released to the landlord after you complete a physical inspection and confirm the move-in. This protects you from fraud.',
        },
        {
          'q': 'Can I cancel a booking?',
          'a': 'Yes. You can cancel from the Bookings tab before your move-in date. A full refund will be processed to your original payment method within 3-5 business days.',
        },
      ],
    },
    {
      'title': 'Payments & Fees',
      'faqs': [
        {
          'q': 'What fees does APEX Housing charge?',
          'a': 'A 5% service fee is added to the tenant\'s total booking cost. Landlords pay a 5% markdown on their listing price. These fees cover escrow processing, inspection coordination, and platform support.',
        },
        {
          'q': 'What payment methods are accepted?',
          'a': 'We accept debit cards, bank transfers, and USSD payments. All transactions are processed through our secure, PCI-compliant payment gateway.',
        },
        {
          'q': 'When is the landlord paid?',
          'a': 'Funds are released from escrow to the landlord\'s account within 24-48 hours after the tenant confirms move-in and the inspection is marked as completed.',
        },
      ],
    },
    {
      'title': 'Landlord Features',
      'faqs': [
        {
          'q': 'How do I list my property?',
          'a': 'Switch to Landlord mode from your Profile, go to My Listings, and tap "Add New". Fill in the property details (title, type, address, rent, bedrooms, bathrooms), upload photos, and submit. Listings go live after a quick verification.',
        },
        {
          'q': 'How do I manage my tenants?',
          'a': 'Go to Profile > Tenant Management to see all active tenants, their lease details, payment history, and contact information. You can message tenants directly from the app.',
        },
        {
          'q': 'How do I view my earnings?',
          'a': 'Navigate to Profile > Earnings & Payouts to see your monthly revenue chart, total earnings, and payout history. Funds are deposited directly to your linked bank account.',
        },
        {
          'q': 'Can I edit a listing after publishing?',
          'a': 'Yes. Go to My Listings, find the property, and tap "Edit". You can update photos, pricing, availability, and description. Changes are reviewed and go live within a few hours.',
        },
      ],
    },
    {
      'title': 'Issues & Safety',
      'faqs': [
        {
          'q': 'What if the property doesn\'t match the listing?',
          'a': 'During your inspection window (24 hours after booking), if the property doesn\'t match the description, you can raise a dispute directly in the app. Our support team will review and process a full refund if the claim is valid.',
        },
        {
          'q': 'How do I report a maintenance issue?',
          'a': 'Go to your active booking and tap "Report Issue". Describe the problem, attach photos if needed, and submit. Your landlord will be notified and you can track the repair status in the app.',
        },
        {
          'q': 'How do I report a user or listing?',
          'a': 'Tap the flag icon on any listing or user profile to submit a report. Our trust & safety team reviews all reports within 24 hours and takes appropriate action.',
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Help Center'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded, size: 28, color: AppColors.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How can we help?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tc.text)),
                      const SizedBox(height: 2),
                      Text('Browse common questions below or contact support', style: TextStyle(fontSize: 13, color: tc.subtitle)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ..._categories.map((cat) {
            final catIndex = _categories.indexOf(cat);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat['title'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tc.text)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: tc.card,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: [BoxShadow(blurRadius: 18, color: tc.shadow)],
                  ),
                  child: Column(
                    children: List.generate((cat['faqs'] as List).length, (fi) {
                      final faq = (cat['faqs'] as List)[fi] as Map<String, String>;
                      final globalIndex = catIndex * 100 + fi;
                      final expanded = _expandedFaq == globalIndex;
                      final isLast = fi == (cat['faqs'] as List).length - 1;
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _expandedFaq = expanded ? -1 : globalIndex),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(faq['q']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: tc.text)),
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
                              child: Text(faq['a']!, style: TextStyle(fontSize: 13, color: tc.subtitle, height: 1.6)),
                            ),
                            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 200),
                          ),
                          if (!isLast) Divider(height: 1, indent: 20, endIndent: 20, color: tc.border),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          }),
        ],
      ),
    );
  }
}
