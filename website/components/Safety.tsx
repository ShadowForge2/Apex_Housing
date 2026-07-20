export default function Safety() {
  const blockedItems = [
    'Phone numbers',
    'Email addresses',
    'External links',
    'Media files',
    'Voice notes',
  ];

  const securityFeatures = [
    {
      icon: (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
          <path d="M7 11V7a5 5 0 0 1 10 0v4" />
        </svg>
      ),
      title: 'End-to-End Security',
      desc: 'Account protection with secure authentication and data encryption.',
    },
    {
      icon: (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
          <circle cx="8.5" cy="7" r="4" />
          <polyline points="17 11 19 13 23 9" />
        </svg>
      ),
      title: 'KYC Verification',
      desc: 'Identity verification maintains a trusted community by reducing fraud.',
    },
    {
      icon: (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
          <polyline points="14 2 14 8 20 8" />
          <line x1="16" y1="13" x2="8" y2="13" />
          <line x1="16" y1="17" x2="8" y2="17" />
        </svg>
      ),
      title: 'Digital Signature',
      desc: 'After KYC approval, users complete a digital signature to access all features.',
    },
    {
      icon: (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
        </svg>
      ),
      title: 'Admin Moderation',
      desc: 'Our moderation team reviews reports and maintains a respectful environment.',
    },
  ];

  return (
    <section id="safety" className="py-24 relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white mb-4">
            Safety & <span className="text-gradient">Trust</span>
          </h2>
          <p className="text-lg text-dark-subtitle max-w-2xl mx-auto">
            Your safety is our top priority. Here&apos;s how we protect you.
          </p>
        </div>

        {/* Messaging Safety */}
        <div className="bg-dark-surface border border-dark-border rounded-3xl p-8 lg:p-12 mb-12">
          <div className="grid lg:grid-cols-2 gap-10 items-center">
            <div>
              <h3 className="text-2xl font-bold text-white mb-4">Secure In-App Messaging</h3>
              <p className="text-dark-subtitle mb-6 leading-relaxed">
                To protect both tenants and landlords, users <strong className="text-white">cannot</strong> send certain content inside APEX Housing chats:
              </p>
              <div className="flex flex-wrap gap-3">
                {blockedItems.map((item, i) => (
                  <span
                    key={i}
                    className="inline-flex items-center gap-2 px-4 py-2 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400 text-sm font-medium"
                  >
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                      <line x1="18" y1="6" x2="6" y2="18" />
                      <line x1="6" y1="6" x2="18" y2="18" />
                    </svg>
                    {item}
                  </span>
                ))}
              </div>
              <p className="text-dark-subtitle mt-6 leading-relaxed">
                Everything stays inside APEX Housing. No external communication that could expose you to scams.
              </p>
            </div>

            <div className="relative">
              <div className="bg-dark-surfaceVariant rounded-2xl border border-dark-border p-6">
                <div className="flex items-center gap-3 mb-4">
                  <div className="w-10 h-10 rounded-full bg-primary-500/20 flex items-center justify-center text-primary-400 text-sm font-bold">TB</div>
                  <div>
                    <p className="text-white text-sm font-medium">Tenant Bot</p>
                    <p className="text-dark-hint text-xs">Online</p>
                  </div>
                </div>
                <div className="space-y-3">
                  <div className="bg-primary-500/10 border border-primary-500/20 rounded-xl rounded-tl-sm px-4 py-3 max-w-[80%]">
                    <p className="text-white text-sm">Hi, I&apos;m interested in the 2BR apartment. When can I schedule a viewing?</p>
                  </div>
                  <div className="bg-dark-surface border border-dark-border rounded-xl rounded-tr-sm px-4 py-3 max-w-[80%] ml-auto">
                    <p className="text-white text-sm">Sure! How about Saturday morning?</p>
                  </div>
                  <div className="bg-primary-500/10 border border-primary-500/20 rounded-xl rounded-tl-sm px-4 py-3 max-w-[80%]">
                    <p className="text-white text-sm">Perfect, see you then!</p>
                  </div>
                </div>
                <div className="mt-4 pt-4 border-t border-dark-border flex items-center gap-2 text-dark-hint text-xs">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                  </svg>
                  All messages are encrypted and moderated
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* KYC Flow */}
        <div className="bg-dark-surface border border-dark-border rounded-3xl p-8 lg:p-12 mb-12">
          <h3 className="text-2xl font-bold text-white mb-8 text-center">KYC Verification Process</h3>
          <div className="flex flex-col md:flex-row items-center justify-center gap-4 md:gap-8">
            {['Sign Up', 'Verify Identity', 'Digital Signature', 'Full Access'].map((step, i) => (
              <div key={i} className="flex items-center gap-4 md:gap-8">
                <div className="flex flex-col items-center text-center">
                  <div className="w-14 h-14 rounded-2xl bg-primary-500/10 border border-primary-500/20 flex items-center justify-center text-primary-400 font-bold text-lg mb-3">
                    {i + 1}
                  </div>
                  <span className="text-sm font-medium text-white">{step}</span>
                  {i === 2 && <span className="text-xs text-dark-hint mt-1">Limited Mode</span>}
                </div>
                {i < 3 && (
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-primary-500/40 hidden md:block">
                    <line x1="5" y1="12" x2="19" y2="12" />
                    <polyline points="12 5 19 12 12 19" />
                  </svg>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Security Features Grid */}
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {securityFeatures.map((f, i) => (
            <div
              key={i}
              className="p-6 bg-dark-surface border border-dark-border rounded-2xl hover:border-primary-500/20 transition-all duration-300"
            >
              <div className="w-12 h-12 rounded-xl bg-primary-500/10 flex items-center justify-center text-primary-400 mb-4">
                {f.icon}
              </div>
              <h4 className="text-lg font-semibold text-white mb-2">{f.title}</h4>
              <p className="text-sm text-dark-subtitle leading-relaxed">{f.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
