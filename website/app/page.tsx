import Header from '@/components/Header';
import Hero from '@/components/Hero';
import WhyApex from '@/components/WhyApex';
import HowItWorks from '@/components/HowItWorks';
import Features from '@/components/Features';
import Safety from '@/components/Safety';
import Testimonials from '@/components/Testimonials';
import FAQ from '@/components/FAQ';
import Download from '@/components/Download';
import Footer from '@/components/Footer';

export default function Home() {
  return (
    <>
      <Header />
      <main>
        <Hero />
        <WhyApex />
        <HowItWorks />
        <Features />
        <Safety />
        <Testimonials />
        <FAQ />
        <Download />
      </main>
      <Footer />
    </>
  );
}
