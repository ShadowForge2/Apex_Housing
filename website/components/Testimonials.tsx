export default function Testimonials() {
  const testimonials = [
    {
      stars: 5,
      text: 'Found my apartment in just two days. The verification process gave me confidence that everything was legitimate.',
      name: 'Amina Bello',
      role: 'Tenant, Lagos',
    },
    {
      stars: 5,
      text: 'Safe communication with my landlord without sharing personal details. The escrow system is a game changer.',
      name: 'Tunde Adesanya',
      role: 'Tenant, Abuja',
    },
    {
      stars: 5,
      text: 'Best rental experience I\'ve had. The platform handles everything from search to payment securely.',
      name: 'Ngozi Eze',
      role: 'Tenant, Port Harcourt',
    },
  ];

  return (
    <section className="py-24 relative">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-white mb-4">
            What Users <span className="text-gradient">Say</span>
          </h2>
          <p className="text-lg text-dark-subtitle max-w-2xl mx-auto">
            Trusted by thousands of tenants and landlords across Nigeria.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          {testimonials.map((t, i) => (
            <div
              key={i}
              className="p-8 bg-dark-surface border border-dark-border rounded-2xl hover:border-primary-500/20 transition-all duration-300"
            >
              {/* Stars */}
              <div className="flex gap-1 mb-4">
                {Array.from({ length: t.stars }).map((_, j) => (
                  <svg key={j} width="18" height="18" viewBox="0 0 24 24" fill="currentColor" className="text-amber-400">
                    <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
                  </svg>
                ))}
              </div>
              <p className="text-dark-subtitle leading-relaxed mb-6">&quot;{t.text}&quot;</p>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-primary-500/20 flex items-center justify-center text-primary-400 text-sm font-bold">
                  {t.name.split(' ').map((n) => n[0]).join('')}
                </div>
                <div>
                  <p className="text-white text-sm font-medium">{t.name}</p>
                  <p className="text-dark-hint text-xs">{t.role}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
