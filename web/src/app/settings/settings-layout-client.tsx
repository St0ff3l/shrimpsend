'use client';

import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { useI18n } from '@/contexts/I18nContext';
import { useMinWidthMd } from '@/hooks/useMediaQuery';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { fetchUserProfile } from '@/lib/api';
import { isAdminEmail } from '@/lib/adminEmails';
import { Button, buttonVariants } from '@/components/ui/button';
import { cn } from '@/lib/utils';

const NAV_ITEMS = [
  { href: '/settings/account', key: 'settings.navAccount' },
  { href: '/settings/language', key: 'settings.navLanguage' },
  { href: '/settings/membership', key: 'settings.navMembership' },
  { href: '/settings/s3', key: 'settings.navS3' },
  { href: '/settings/appearance', key: 'settings.navAppearance' },
  { href: '/settings/fonts', key: 'settings.navFonts' },
  { href: '/settings/shortcuts', key: 'settings.navShortcuts' },
  { href: '/settings/about', key: 'settings.navAbout' },
] as const;

function navActive(pathname: string, href: string) {
  if (href === '/settings/s3') return pathname.startsWith('/settings/s3');
  return pathname === href;
}

export default function SettingsLayout({ children }: { children: React.ReactNode }) {
  const { t } = useI18n();
  const pathname = usePathname();
  const isWide = useMinWidthMd();
  const { accessToken, isReady, logout } = useAuth();
  const router = useRouter();
  const [showAdminLink, setShowAdminLink] = useState(false);

  useEffect(() => {
    if (!isReady) return;
    if (!accessToken) {
      router.push('/login');
    }
  }, [isReady, accessToken, router]);

  useEffect(() => {
    if (!accessToken || !isWide) {
      queueMicrotask(() => setShowAdminLink(false));
      return;
    }
    fetchUserProfile()
      .then((p) => setShowAdminLink(isAdminEmail(p.email)))
      .catch(() => setShowAdminLink(false));
  }, [accessToken, isWide]);

  const handleLogout = async () => {
    await logout();
    router.push('/login');
  };

  if (!isReady) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-3 text-muted-foreground animate-app-fade-in">
        <div
          className="size-8 shrink-0 rounded-full border-2 border-primary/25 border-t-primary motion-safe:animate-spin"
          aria-hidden
        />
        <span className="text-sm">{t('common.loading')}</span>
      </div>
    );
  }
  if (!accessToken) return null;

  if (!isWide) {
    return <>{children}</>;
  }

  return (
    <div className="min-h-dvh text-foreground">
      <div className="mx-auto flex min-h-dvh max-w-6xl flex-row">
        <aside className="flex w-56 shrink-0 flex-col border-r border-border/60 bg-card/50 p-4 backdrop-blur-xl">
          <div className="mb-6 flex flex-wrap items-center gap-2">
            <Link href="/chat" className="text-muted-foreground transition-colors hover:text-foreground">
              ← {t('common.back')}
            </Link>
            <h1 className="font-display text-lg font-semibold tracking-tight">{t('settings.title')}</h1>
          </div>
          <nav className="flex flex-col gap-0.5" aria-label={t('settings.navAriaLabel')}>
            {NAV_ITEMS.map(({ href, key }) => (
              <Link
                key={href}
                href={href}
                className={cn(
                  'w-full rounded-xl px-3 py-2.5 text-left text-sm transition-colors duration-150',
                  navActive(pathname, href)
                    ? 'bg-primary/10 font-medium text-foreground ring-1 ring-primary/15'
                    : 'text-muted-foreground hover:bg-muted/70 hover:text-foreground',
                )}
                aria-current={navActive(pathname, href) ? 'page' : undefined}
              >
                {t(key)}
              </Link>
            ))}
          </nav>
          <div className="mt-auto flex flex-col gap-2 pt-6">
            {showAdminLink && (
              <Link href="/admin" className={cn(buttonVariants({ variant: 'outline' }), 'w-full justify-center')}>
                {t('settings.adminLink')}
              </Link>
            )}
            <Button variant="destructive" className="w-full" onClick={handleLogout}>
              {t('settings.logout')}
            </Button>
          </div>
        </aside>
        <main className="min-h-0 flex-1 overflow-y-auto p-6 sm:p-8">{children}</main>
      </div>
    </div>
  );
}
