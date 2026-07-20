'use client';

export default function Hero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden pt-20">
      {/* Background effects */}
      <div className="absolute inset-0 bg-gradient-to-br from-dark-bg via-dark-surface to-dark-bg" />
      <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-primary-500/10 rounded-full blur-3xl animate-pulse-slow" />
      <div className="absolute bottom-1/4 right-1/4 w-80 h-80 bg-primary-400/8 rounded-full blur-3xl animate-pulse-slow" style={{ animationDelay: '2s' }} />

      <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-16 items-center">
          {/* Text */}
          <div className="text-center lg:text-left">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-primary-500/10 border border-primary-500/20 rounded-full mb-8">
              <span className="w-2 h-2 bg-primary-400 rounded-full animate-pulse" />
              <span className="text-sm font-medium text-primary-300">Nigeria&apos;s Trusted Rental Platform</span>
            </div>

            <h1 className="text-4xl sm:text-5xl lg:text-6xl xl:text-7xl font-extrabold leading-tight mb-6">
              <span className="text-white">Rent Smarter.</span>
              <br />
              <span className="text-gradient">Connect Securely.</span>
              <br />
              <span className="text-white">Live Better.</span>
            </h1>

            <p className="text-lg sm:text-xl text-dark-subtitle max-w-xl mx-auto lg:mx-0 mb-10 leading-relaxed">
              APEX Housing connects tenants and landlords through a secure, verified platform designed to make renting safer, faster, and more transparent.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center lg:justify-start">
              <a
                href="#download"
                className="inline-flex items-center justify-center gap-3 px-7 py-4 bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-400 hover:to-primary-500 text-white font-semibold rounded-2xl transition-all duration-200 shadow-xl shadow-primary-500/25 hover:shadow-primary-500/40 hover:-translate-y-0.5"
              >
                <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M3 20.5V3.5C3 2.91 3.34 2.39 3.84 2.15L13.69 12L3.84 21.85C3.34 21.61 3 21.09 3 20.5M16.81 15.12L6.05 21.34L14.54 12.85L16.81 15.12M20.16 10.81C20.5 11.08 20.75 11.5 20.75 12C20.75 12.5 20.5 12.92 20.16 13.19L17.89 14.5L15.39 12L17.89 9.5L20.16 10.81M6.05 2.66L16.81 8.88L14.54 11.15L6.05 2.66Z" />
                </svg>
                Google Play
              </a>
              <a
                href="#download"
                className="inline-flex items-center justify-center gap-3 px-7 py-4 bg-dark-surface border border-dark-border hover:border-primary-500/30 text-white font-semibold rounded-2xl transition-all duration-200 hover:-translate-y-0.5"
              >
                <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M18.71 19.5C17.88 20.74 17 21.95 15.66 21.97C14.32 22 13.89 21.18 12.37 21.18C10.84 21.18 10.37 21.95 9.1 22C7.79 22.05 6.8 20.68 5.96 19.47C4.25 16.56 2.93 11.3 4.7 7.72C5.57 5.94 7.36 4.86 9.28 4.84C10.56 4.81 11.78 5.72 12.57 5.72C13.36 5.72 14.85 4.62 16.4 4.8C17.06 4.83 18.82 5.06 19.96 6.66C19.87 6.72 17.78 7.92 17.81 10.45C17.84 13.46 20.46 14.46 20.49 14.47C20.46 14.54 20.07 15.92 18.71 19.5M13 3.5C13.73 2.67 14.94 2.04 15.94 2C16.07 3.17 15.6 4.35 14.9 5.19C14.21 6.04 13.07 6.7 11.95 6.61C11.8 5.46 12.36 4.26 13 3.5Z" />
                </svg>
                App Store
              </a>
              <a
                href="#download"
                className="inline-flex items-center justify-center gap-3 px-7 py-4 bg-dark-surface border border-dark-border hover:border-primary-500/30 text-white font-semibold rounded-2xl transition-all duration-200 hover:-translate-y-0.5"
              >
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                  <polyline points="7 10 12 15 17 10" />
                  <line x1="12" y1="15" x2="12" y2="3" />
                </svg>
                Download APK
              </a>
            </div>
          </div>

          {/* Phone mockup */}
          <div className="relative flex justify-center lg:justify-end">
            <div className="relative animate-float">
              {/* Glow */}
              <div className="absolute -inset-4 bg-gradient-to-r from-primary-500/20 to-primary-600/20 rounded-[3rem] blur-2xl" />
              {/* Phone frame */}
              <div className="relative w-72 h-[580px] bg-dark-surface rounded-[3rem] border-2 border-dark-border overflow-hidden shadow-2xl shadow-primary-500/10">
                {/* Notch */}
                <div className="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-7 bg-dark-bg rounded-b-2xl z-10" />
                {/* Screen content placeholder */}
                <div className="w-full h-full bg-gradient-to-b from-primary-500/10 via-dark-surface to-dark-bg flex flex-col items-center justify-center p-6">
                  <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-primary-400 to-primary-600 flex items-center justify-center mb-4 shadow-lg shadow-primary-500/30">
                    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
                      <polyline points="9 22 9 12 15 12 15 22" />
                    </svg>
                  </div>
                  <p className="text-white font-bold text-lg mb-1">APEX Housing</p>
                  <p className="text-dark-subtitle text-sm text-center mb-6">Find your perfect home</p>
                  {/* Fake property card */}
                  <div className="w-full bg-dark-surfaceVariant rounded-xl p-3 border border-dark-border">
                    <div className="w-full h-24 bg-primary-500/10 rounded-lg mb-3" />
                    <div className="h-3 bg-dark-border rounded-full w-3/4 mb-2" />
                    <div className="h-3 bg-dark-border rounded-full w-1/2 mb-3" />
                    <div className="flex items-center justify-between">
                      <div className="h-4 bg-primary-500/30 rounded-full w-20" />
                      <div className="h-3 bg-dark-border rounded-full w-16" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
