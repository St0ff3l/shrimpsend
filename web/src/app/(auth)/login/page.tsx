'use client';

import { LoginAuthCard } from '@/components/auth/login-auth-card';
import { AuthDownloadPanel } from '@/components/auth/auth-download-panel';
import { SiteFooter } from '@/components/landing/SiteFooter';
import { SiteNav } from '@/components/landing/SiteNav';

export default function LoginPage() {
  return (
    <div className="landing-shell relative min-h-dvh overflow-hidden text-foreground">
      <div className="landing-glow-orb -left-40 top-20 h-80 w-80 opacity-70 motion-safe:animate-app-glow-drift" aria-hidden />
      <div className="landing-glow-orb right-[-8rem] bottom-10 h-[26rem] w-[26rem] opacity-45 motion-safe:animate-app-glow-drift" aria-hidden />

      <SiteNav active="home" showOpenApp={false} />

      <div className="relative z-[1] mx-auto grid w-full max-w-6xl gap-10 px-5 pb-10 pt-6 lg:min-h-[calc(100dvh-5rem)] lg:grid-cols-[minmax(360px,420px)_1fr] lg:items-center lg:px-8">
        <section className="mx-auto w-full max-w-[440px] lg:mx-0">
          <LoginAuthCard />
        </section>

        <AuthDownloadPanel />
      </div>

      <SiteFooter />
    </div>
  );
}
