export default function WhyApex() {
  const problems = [
    { icon: '🚫', text: 'Fake listings' },
    { icon: '⚠️', text: 'Scammers' },
    { icon: '😤', text: 'Difficult communication' },
    { icon: '💸', text: 'Hidden fees' },
    { icon: '📄', text: 'Poor documentation' },
  ];

  const solutions = [
    {
      icon: (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
        </svg>
      ),
      title: 'Verified Properties',
      desc: 'Every listing is reviewed and verified before going live.',
    },
    {
      icon: (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
          <circle cx="8.5" cy="7" r="4" />
          <polyline points="17 11 19 13 23 9" />
        </svg>
      ),
      title: 'KYC Verified Users',
      desc: 'Every user is identity-verified for your safety.',
    },
    {
      icon: (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
          <path d="M7 11V7a5 5 0 0 1 10 0v4" />
        </svg>
      ),
      title: 'Secure Escrow',
      desc: 'Your rent payments are held safely until move-in is confirmed.',
    },
    {
      icon: (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
        </svg>
      ),
      title: 'Safe Messaging',
      desc: 'Chat securely within the platform — no phone numbers or external links needed.',
    },
  ];

  return (
    <section className="py-24 relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white mb-4">
            Why <span className="text-gradient">APEX Housing</span>?
          </h2>
          <p className="text-lg text-dark-subtitle max-w-2xl mx-auto">
            Traditional renting is broken. We built something better.
          </p>
        </div>

        {/* Problems */}
        <div className="bg-dark-surface border border-dark-border rounded-2xl p-8 mb-12">
          <h3 className="text-xl font-semibold text-white mb-6 text-center">The Problem with Traditional Renting</h3>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-4">
            {problems.map((p, i) => (
              <div key={i} className="flex flex-col items-center gap-2 p-4 bg-dark-surfaceVariant rounded-xl border border-dark-border">
                <span className="text-2xl">{p.icon}</span>
                <span className="text-sm text-dark-subtitle text-center">{p.text}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Solutions */}
        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {solutions.map((s, i) => (
            <div
              key={i}
              className="group p-6 bg-dark-surface border border-dark-border rounded-2xl hover:border-primary-500/30 transition-all duration-300 hover:-translate-y-1"
            >
              <div className="w-12 h-12 rounded-xl bg-primary-500/10 flex items-center justify-center text-primary-400 mb-4 group-hover:bg-primary-500/20 transition-colors">
                {s.icon}
              </div>
              <h4 className="text-lg font-semibold text-white mb-2">{s.title}</h4>
              <p className="text-sm text-dark-subtitle leading-relaxed">{s.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
