import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'APEX Housing - Rent Smarter. Connect Securely. Live Better.',
  description:
    'APEX Housing connects tenants and landlords through a secure, verified platform designed to make renting safer, faster, and more transparent.',
  keywords: [
    'rental platform',
    'housing',
    'Nigeria',
    'property',
    'tenant',
    'landlord',
    'secure renting',
    'KYC verified',
    'escrow payments',
  ],
  openGraph: {
    title: 'APEX Housing - Rent Smarter. Connect Securely. Live Better.',
    description:
      'APEX Housing connects tenants and landlords through a secure, verified platform designed to make renting safer, faster, and more transparent.',
    type: 'website',
    url: 'https://apex-housing.online',
    siteName: 'APEX Housing',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'APEX Housing - Rent Smarter. Connect Securely. Live Better.',
    description:
      'APEX Housing connects tenants and landlords through a secure, verified platform designed to make renting safer, faster, and more transparent.',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="scroll-smooth">
      <body className="bg-dark-bg text-dark-text antialiased">{children}</body>
    </html>
  );
}
