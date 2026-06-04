'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { useI18n } from '@/contexts/I18nContext';
import { BrandLogo } from '@/components/brand/BrandLogo';
import type { LocaleTagValue } from '@/lib/localeRegionPreferences';
import { localizedDocsHref, localizedHashHref, localizedHomeHref, localeTagToPath, switchLocalePath } from '@/lib/i18nRouting';
import { buttonVariants } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { Check, ChevronDown, Languages, Menu, X } from 'lucide-react';

type SiteNavProps = {
  active: 'home' | 'docs';
  showOpenApp?: boolean;
};

const localeOptions: Array<{ value: LocaleTagValue; labelKey: string }> = [
  { value: 'zh_CN', labelKey: 'settings.localeRegion.optionZh' },
  { value: 'en', labelKey: 'settings.localeRegion.optionEn' },
];

export function SiteNav({ active, showOpenApp = true }: SiteNavProps) {
  const { localeTag, setLocaleTag, t } = useI18n();
  const pathname = usePathname();
  const router = useRouter();
  const [localeOpen, setLocaleOpen] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const navRef = useRef<HTMLElement | null>(null);
  const localeMenuRef = useRef<HTMLDivElement | null>(null);
  const activeLocale = localeOptions.find((option) => option.value === localeTag) ?? localeOptions[0]!;
  const localePath = localeTagToPath(localeTag);
  const navItems = [
    { id: 'home', href: localizedHomeHref(localePath), key: 'landing.navHome' },
    { id: 'docs', href: localizedDocsHref(localePath, 'intro'), key: 'landing.navDocs' },
    { id: 'pricing', href: localizedHashHref(localePath, 'pricing'), key: 'landing.navPricing' },
    { id: 'faq', href: localizedHashHref(localePath, 'faq'), key: 'landing.navFaq' },
  ] as const;

  useEffect(() => {
    if (!localeOpen && !mobileMenuOpen) return;
    const onPointerDown = (event: PointerEvent) => {
      const target = event.target as Node;
      if (localeOpen && !localeMenuRef.current?.contains(target)) {
        setLocaleOpen(false);
      }
      if (mobileMenuOpen && !navRef.current?.contains(target)) {
        setMobileMenuOpen(false);
      }
    };
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setLocaleOpen(false);
        setMobileMenuOpen(false);
      }
    };
    window.addEventListener('pointerdown', onPointerDown);
    window.addEventListener('keydown', onKeyDown);
    return () => {
      window.removeEventListener('pointerdown', onPointerDown);
      window.removeEventListener('keydown', onKeyDown);
    };
  }, [localeOpen, mobileMenuOpen]);

  const pickLocale = (tag: LocaleTagValue) => {
    if (tag !== localeTag) {
      setLocaleTag(tag);
      router.push(switchLocalePath(pathname, localeTagToPath(tag)));
    }
    setLocaleOpen(false);
  };

  return (
    <nav ref={navRef} className="relative z-50 mx-auto flex w-full max-w-7xl items-center justify-between gap-2 px-4 py-5 sm:gap-4 sm:px-5 md:px-8">
      <Link href={localizedHomeHref(localePath)} className="flex items-center gap-2.5">
        <BrandLogo
          size={36}
          alt={t('auth.brandAlt')}
          className="shadow-lg shadow-primary/15 ring-1 ring-white/10"
          priority
        />
        <span className="font-display text-lg font-semibold tracking-tight max-[360px]:hidden">{t('common.brandName')}</span>
      </Link>

      <div className="hidden items-center gap-2 rounded-full border border-white/10 bg-white/[0.035] p-1 text-sm text-muted-foreground backdrop-blur-xl md:flex">
        {navItems.map((item) => {
          const isActive = item.id === active;
          return (
            <Link
              key={item.id}
              href={item.href}
              aria-current={isActive ? 'page' : undefined}
              className={cn(
                'rounded-full px-3 py-1.5 transition-colors',
                isActive
                  ? 'bg-primary/14 font-medium text-foreground ring-1 ring-primary/20'
                  : 'hover:bg-white/[0.055] hover:text-foreground',
              )}
            >
              {t(item.key)}
            </Link>
          );
        })}
      </div>

      <div className="flex items-center gap-1.5 sm:gap-2">
        {showOpenApp ? (
          <Link href="/chat" className={cn(buttonVariants({ variant: 'outline', size: 'sm' }), 'rounded-full bg-white/[0.04] px-3 sm:px-4')}>
            {t('landing.openApp')}
          </Link>
        ) : null}
        <div ref={localeMenuRef} className="relative">
          <button
            type="button"
            onClick={() => setLocaleOpen((v) => !v)}
            aria-haspopup="menu"
            aria-expanded={localeOpen}
            className="inline-flex h-8 items-center gap-1.5 rounded-full border border-white/10 bg-white/[0.04] px-2.5 text-xs font-medium text-foreground outline-none transition-colors hover:bg-white/[0.07] focus:border-primary/40 focus:ring-2 focus:ring-primary/20"
          >
            <Languages className="size-3.5 text-primary/85" aria-hidden />
            <span className="hidden sm:inline">{t(activeLocale.labelKey)}</span>
            <ChevronDown className={cn('size-3.5 text-muted-foreground transition-transform', localeOpen && 'rotate-180')} aria-hidden />
          </button>

          {localeOpen && (
            <div
              role="menu"
              className="absolute right-0 top-10 z-50 w-40 overflow-hidden rounded-2xl border border-white/12 bg-background/95 p-1.5 shadow-2xl shadow-black/30 ring-1 ring-white/10 backdrop-blur-xl animate-in fade-in zoom-in-95 duration-150"
            >
              {localeOptions.map((option) => {
                const selected = option.value === localeTag;
                return (
                  <button
                    key={option.value}
                    type="button"
                    role="menuitemradio"
                    aria-checked={selected}
                    onClick={() => pickLocale(option.value)}
                    className={cn(
                      'flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-sm transition-colors',
                      selected
                        ? 'bg-primary/14 font-medium text-foreground'
                        : 'text-muted-foreground hover:bg-white/[0.06] hover:text-foreground',
                    )}
                  >
                    <Check className={cn('size-4 text-primary', selected ? 'opacity-100' : 'opacity-0')} aria-hidden />
                    <span>{t(option.labelKey)}</span>
                  </button>
                );
              })}
            </div>
          )}
        </div>
        <button
          type="button"
          onClick={() => {
            setMobileMenuOpen((v) => !v);
            setLocaleOpen(false);
          }}
          aria-label={mobileMenuOpen ? t('landing.navCloseMenu') : t('landing.navMenu')}
          aria-expanded={mobileMenuOpen}
          aria-controls="mobile-site-nav"
          className="inline-flex size-8 items-center justify-center rounded-full border border-white/10 bg-white/[0.04] text-foreground outline-none transition-colors hover:bg-white/[0.07] focus:border-primary/40 focus:ring-2 focus:ring-primary/20 md:hidden"
        >
          {mobileMenuOpen ? <X className="size-4" aria-hidden /> : <Menu className="size-4" aria-hidden />}
        </button>
      </div>

      {mobileMenuOpen ? (
        <div
          id="mobile-site-nav"
          className="absolute inset-x-4 top-[4.5rem] z-50 overflow-hidden rounded-3xl border border-white/12 bg-background/94 p-2 shadow-2xl shadow-black/30 ring-1 ring-white/10 backdrop-blur-2xl md:hidden"
        >
          <div className="grid gap-1">
            {navItems.map((item) => {
              const isActive = item.id === active;
              return (
                <Link
                  key={item.id}
                  href={item.href}
                  aria-current={isActive ? 'page' : undefined}
                  onClick={() => setMobileMenuOpen(false)}
                  className={cn(
                    'rounded-2xl px-4 py-3 text-sm transition-colors',
                    isActive
                      ? 'bg-primary/14 font-medium text-foreground ring-1 ring-primary/20'
                      : 'text-muted-foreground hover:bg-white/[0.06] hover:text-foreground',
                  )}
                >
                  {t(item.key)}
                </Link>
              );
            })}
          </div>
        </div>
      ) : null}
    </nav>
  );
}
