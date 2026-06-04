'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { useI18n } from '@/contexts/I18nContext';
import { ChatProvider } from '@/contexts/ChatContext';
import { MainLayout } from '@/components/layout/MainLayout';

export default function ChatPage() {
  const { t } = useI18n();
  const { userId, accessToken, isReady } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!isReady) return;
    if (!accessToken || !userId) {
      router.push('/login');
    }
  }, [isReady, accessToken, userId, router]);

  if (!isReady || !accessToken || !userId) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-3 text-muted-foreground animate-app-fade-in">
        <div
          className="size-8 shrink-0 rounded-full border-2 border-primary/25 border-t-primary motion-safe:animate-spin"
          aria-hidden
        />
        <span className="text-sm tracking-wide">{t('common.loading')}</span>
      </div>
    );
  }

  return (
    <ChatProvider>
      <MainLayout />
    </ChatProvider>
  );
}
