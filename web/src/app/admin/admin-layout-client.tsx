'use client';

import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { fetchUserProfile } from '@/lib/api/user';
import { isAdminEmail } from '@/lib/adminEmails';
import { logger } from '@/lib/logger';
import { buttonVariants } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { cn } from '@/lib/utils';

const TAG = 'adminLayout';

type GateState = 'loading' | 'allowed' | 'forbidden';

/**
 * 后台路由统一门禁：已登录且邮箱在管理员白名单内才展示子页面。
 */
export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const { accessToken, isReady } = useAuth();
  const router = useRouter();
  const [gate, setGate] = useState<GateState>('loading');

  useEffect(() => {
    if (!isReady) return;
    if (!accessToken) {
      router.replace('/login');
      return;
    }
    let cancelled = false;
    (async () => {
      try {
        const p = await fetchUserProfile();
        if (cancelled) return;
        setGate(isAdminEmail(p.email) ? 'allowed' : 'forbidden');
      } catch (e) {
        logger.warn(TAG, 'profile failed', e);
        if (!cancelled) setGate('forbidden');
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [isReady, accessToken, router]);

  if (!isReady) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-muted-foreground text-sm">加载中…</div>
    );
  }

  if (!accessToken) {
    return null;
  }

  if (gate === 'loading') {
    return (
      <div className="flex min-h-dvh items-center justify-center text-muted-foreground text-sm">验证管理员权限…</div>
    );
  }

  if (gate === 'forbidden') {
    return (
      <div className="mx-auto max-w-lg px-4 py-16">
        <Card>
          <CardHeader>
            <CardTitle>无权访问</CardTitle>
            <CardDescription>当前账号不在后台管理员邮箱白名单中。</CardDescription>
          </CardHeader>
          <CardContent>
            <Link href="/chat" className={cn(buttonVariants())}>
              返回会话
            </Link>
          </CardContent>
        </Card>
      </div>
    );
  }

  return <>{children}</>;
}
