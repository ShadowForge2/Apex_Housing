export default function Features() {
  const tenantFeatures = [
    'Verified properties',
    'Smart property search',
    'Favorite listings',
    'Secure landlord chat',
    'Property reports',
    'Digital agreements',
    'Rental history',
    'Saved searches',
  ];

  const landlordFeatures = [
    'Property management',
    'Tenant screening',
    'Property analytics',
    'Rental requests',
    'Lease management',
    'Notifications',
    'Tenant communication',
  ];

  const sharedFeatures = [
    'KYC verification',
    'Secure messaging',
    'Push notifications',
    'In-app support',
    'Privacy protection',
    'Fast performance',
  ];

  return (
    <section id="features" className="py-24 relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white mb-4">
            Platform <span className="text-gradient">Features</span>
          </h2>
          <p className="text-lg text-dark-subtitle max-w-2xl mx-auto">
            Everything you need for a safe, modern rental experience.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          {/* Tenants */}
          <div className="bg-dark-surface border border-dark-border rounded-2xl p-8 hover:border-primary-500/20 transition-all duration-300">
            <div className="w-14 h-14 rounded-2xl bg-blue-500/10 flex items-center justify-center text-blue-400 mb-6">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                <circle cx="12" cy="7" r="4" />
              </svg>
            </div>
            <h3 className="text-xl font-bold text-white mb-6">For Tenants</h3>
            <ul className="space-y-3">
              {tenantFeatures.map((f, i) => (
                <li key={i} className="flex items-center gap-3 text-dark-subtitle">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" className="text-primary-400 shrink-0">
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                  {f}
                </li>
              ))}
            </ul>
          </div>

          {/* Landlords */}
          <div className="bg-dark-surface border border-dark-border rounded-2xl p-8 hover:border-primary-500/20 transition-all duration-300">
            <div className="w-14 h-14 rounded-2xl bg-emerald-500/10 flex items-center justify-center text-emerald-400 mb-6">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
                <polyline points="9 22 9 12 15 12 15 22" />
              </svg>
            </div>
            <h3 className="text-xl font-bold text-white mb-6">For Landlords</h3>
            <ul className="space-y-3">
              {landlordFeatures.map((f, i) => (
                <li key={i} className="flex items-center gap-3 text-dark-subtitle">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" className="text-emerald-400 shrink-0">
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                  {f}
                </li>
              ))}
            </ul>
          </div>

          {/* Everyone */}
          <div className="bg-dark-surface border border-dark-border rounded-2xl p-8 hover:border-primary-500/20 transition-all duration-300">
            <div className="w-14 h-14 rounded-2xl bg-primary-500/10 flex items-center justify-center text-primary-400 mb-6">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
              </svg>
            </div>
            <h3 className="text-xl font-bold text-white mb-6">For Everyone</h3>
            <ul className="space-y-3">
              {sharedFeatures.map((f, i) => (
                <li key={i} className="flex items-center gap-3 text-dark-subtitle">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" className="text-primary-400 shrink-0">
                    <polyline points="20 6 9 17 4 12" />
                  </svg>
                  {f}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}
