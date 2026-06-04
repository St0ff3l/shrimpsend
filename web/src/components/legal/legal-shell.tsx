'use client';

import Link from 'next/link';
import { useI18n } from '@/contexts/I18nContext';

export function LegalShell({ children }: { children: React.ReactNode }) {
  const { t } = useI18n();
  return (
    <>
      <header className="sticky top-0 z-20 border-b border-border/80 bg-background/90 backdrop-blur-md">
        <div className="mx-auto flex h-12 max-w-3xl items-center px-4">
          <Link href="/login" className="text-sm font-medium text-primary underline-offset-4 hover:underline">
            ← {t('legal.backToLogin')}
          </Link>
        </div>
      </header>
      <div className="mx-auto max-w-3xl px-4 py-8">{children}</div>
    </>
  );
}
