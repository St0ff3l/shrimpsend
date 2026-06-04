'use client';

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { setOnAuthExpired } from '@/lib/api';
import { useAuth } from '@/contexts/AuthContext';

/**
 * 注册 401 且 refresh 失败时的跳转：logout + router.replace('/login')，
 * 避免用 window.location 导致历史里留下 /devices、/settings，Back 会回到未授权页。
 */
export function AuthExpiredRedirect() {
  const router = useRouter();
  const { logout } = useAuth();

  useEffect(() => {
    setOnAuthExpired(() => {
      logout();
      router.replace('/login');
    });
    return () => setOnAuthExpired(null);
  }, [logout, router]);

  return null;
}
