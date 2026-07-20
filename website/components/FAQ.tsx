'use client';

import { useState } from 'react';

export default function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  const faqs = [
    {
      q: 'Do I need KYC to use APEX Housing?',
      a: 'You can browse properties without KYC, but to chat with landlords, make bookings, and access all features, you need to complete identity verification. This protects everyone on the platform.',
    },
    {
      q: 'Is APEX Housing free?',
      a: 'Creating an account and browsing properties is completely free. Landlords pay a small fee when a booking is completed. There are no hidden charges.',
    },
    {
      q: 'Can landlords list multiple properties?',
      a: 'Yes! Landlords can list as many properties as they want. Each listing goes through our verification process before going live.',
    },
    {
      q: 'Can I contact landlords outside the app?',
      a: 'For your safety, all communication happens within APEX Housing. We don\'t share phone numbers, emails, or allow external links in chats to prevent scams.',
    },
    {
      q: 'How secure is my information?',
      a: 'We use industry-standard encryption for all data. Your personal information is never shared with other users without your consent. KYC documents are securely stored and processed.',
    },
    {
      q: 'Can I download the APK directly?',
      a: 'Yes! If you can\'t access the Google Play Store, you can download the APK directly from our website. The APK is the same secure version available on the Play Store.',
    },
    {
      q: 'How do I report abuse or a suspicious listing?',
      a: 'Every property listing and user profile has a Report button. You can also contact our support team directly through the in-app help center. All reports are reviewed within 24 hours.',
    },
  ];

  return (
    <section id="faq" className="py-24 relative">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white mb-4">
            Frequently Asked <span className="text-gradient">Questions</span>
          </h2>
        </div>

        <div className="space-y-3">
          {faqs.map((faq, i) => (
            <div
              key={i}
              className="bg-dark-surface border border-dark-border rounded-2xl overflow-hidden transition-all duration-300 hover:border-primary-500/20"
            >
              <button
                onClick={() => setOpenIndex(openIndex === i ? null : i)}
                className="w-full flex items-center justify-between p-6 text-left"
              >
                <span className="text-white font-medium pr-4">{faq.q}</span>
                <svg
                  width="20"
                  height="20"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  className={`text-primary-400 shrink-0 transition-transform duration-200 ${
                    openIndex === i ? 'rotate-180' : ''
                  }`}
                >
                  <polyline points="6 9 12 15 18 9" />
                </svg>
              </button>
              {openIndex === i && (
                <div className="px-6 pb-6">
                  <p className="text-dark-subtitle leading-relaxed">{faq.a}</p>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
