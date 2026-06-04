'use client';

import { useAuth } from '@/contexts/AuthContext';
import { useI18n } from '@/contexts/I18nContext';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { ArrowLeft, SearchX } from 'lucide-react';

export default function SearchPage() {
  const { t } = useI18n();
  const { accessToken, isReady } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (isReady && !accessToken) {
      router.push('/login');
    }
  }, [isReady, accessToken, router]);

  if (!isReady || !accessToken) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-3 text-muted-foreground">
        <div
          className="size-8 shrink-0 rounded-full border-2 border-primary/25 border-t-primary motion-safe:animate-spin"
          aria-hidden
        />
        <span className="text-sm">{t('common.loading')}</span>
      </div>
    );
  }

  return (
    <div className="flex h-dvh flex-col text-foreground animate-app-fade-in">
      <header className="surface-glass z-20 flex shrink-0 items-center gap-2 border-b px-4 py-3">
        <Button variant="ghost" size="sm" onClick={() => router.back()} className="shrink-0 p-1.5">
          <ArrowLeft className="w-5 h-5" />
        </Button>
        <h1 className="text-sm font-semibold">{t('search.title')}</h1>
      </header>

      <main className="flex min-h-0 flex-1 items-center justify-center p-6">
        <div className="max-w-sm rounded-2xl border bg-card/85 p-6 text-center shadow-sm">
          <SearchX className="mx-auto mb-3 size-8 text-muted-foreground" />
          <h2 className="mb-2 text-base font-semibold">{t('search.localOnlyTitle')}</h2>
          <p className="text-sm leading-relaxed text-muted-foreground">{t('search.localOnlyBody')}</p>
        </div>
      </main>
    </div>
  );
}
