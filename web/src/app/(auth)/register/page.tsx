'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState, useRef, useCallback } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useI18n } from '@/contexts/I18nContext';
import { formatUiMessage } from '@/lib/uiMessage';
import { logger } from '@/lib/logger';
import { AuthDownloadPanel } from '@/components/auth/auth-download-panel';
import { SiteFooter } from '@/components/landing/SiteFooter';
import { SiteNav } from '@/components/landing/SiteNav';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent } from '@/components/ui/card';
import { sendVerificationCode } from '@/lib/api/auth';
import {
  Mail, Lock, User, ShieldCheck,
  Eye, EyeOff, AlertCircle, Loader2,
} from 'lucide-react';
import { LegalDocLinks } from '@/components/auth/legal-doc-links';

const TAG = 'register';

function getPostAuthRedirect(): string {
  if (typeof window === 'undefined') return '/chat';
  const next = new URLSearchParams(window.location.search).get('next')?.trim();
  if (next && next.startsWith('/') && !next.startsWith('//')) return next;
  return '/chat';
}

export default function RegisterPage() {
  const router = useRouter();
  const { t } = useI18n();
  const { register } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [username, setUsername] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [codeSending, setCodeSending] = useState(false);
  const [codeCooldown, setCodeCooldown] = useState(0);
  const cooldownRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const startCooldown = useCallback(() => {
    setCodeCooldown(60);
    cooldownRef.current = setInterval(() => {
      setCodeCooldown((prev) => {
        if (prev <= 1) {
          if (cooldownRef.current) clearInterval(cooldownRef.current);
          cooldownRef.current = null;
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  }, []);

  const handleSendCode = async () => {
    if (!email.trim()) {
      setError('auth.enterEmailFirst');
      return;
    }
    setError('');
    setCodeSending(true);
    try {
      await sendVerificationCode(email);
      startCooldown();
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'auth.sendFailed';
      setError(msg);
    } finally {
      setCodeSending(false);
    }
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    logger.info(TAG, 'submit register email=', email.trim());
    try {
      await register(email, password, code, username || undefined);
      router.push(getPostAuthRedirect());
      router.refresh();
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'auth.requestFailed';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="landing-shell relative min-h-dvh overflow-hidden text-foreground">
      <div className="landing-glow-orb -left-40 top-20 h-80 w-80 opacity-70 motion-safe:animate-app-glow-drift" aria-hidden />
      <div className="landing-glow-orb right-[-8rem] bottom-10 h-[26rem] w-[26rem] opacity-45 motion-safe:animate-app-glow-drift" aria-hidden />

      <SiteNav active="home" showOpenApp={false} />

      <div className="relative z-[1] mx-auto grid w-full max-w-6xl gap-10 px-5 pb-10 pt-6 lg:min-h-[calc(100dvh-5rem)] lg:grid-cols-[minmax(360px,420px)_1fr] lg:items-center lg:px-8">
        <section className="mx-auto w-full max-w-[440px] lg:mx-0">
        <Card className="border-border/80 bg-card/92 shadow-xl shadow-black/8 backdrop-blur-xl ring-1 ring-border/40 dark:shadow-black/25 motion-safe:animate-app-fade-up">
          <CardContent className="pt-6">
            <div className="mb-6 flex flex-col items-center text-center">
              <h1 className="font-display text-2xl font-semibold tracking-tight">{t('auth.registerPageTitle')}</h1>
              <p className="mt-1.5 max-w-sm text-sm text-muted-foreground">{t('auth.registerPageSubtitle')}</p>
            </div>
            <form onSubmit={submit} className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="reg-email">{t('auth.email')}</Label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/60" />
                  <Input
                    id="reg-email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="your@email.com"
                    className="pl-9"
                    required
                  />
                </div>
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="reg-username">{t('auth.usernameOptional')}</Label>
                <div className="relative">
                  <User className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/60" />
                  <Input
                    id="reg-username"
                    type="text"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    placeholder={t('auth.displayNamePlaceholder')}
                    maxLength={64}
                    className="pl-9"
                  />
                </div>
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="reg-password">{t('auth.password')}</Label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/60" />
                  <Input
                    id="reg-password"
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="pl-9 pr-9"
                    required
                    minLength={6}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword((v) => !v)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground/60 transition-colors hover:text-muted-foreground"
                    tabIndex={-1}
                  >
                    {showPassword ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4" />}
                  </button>
                </div>
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="reg-code">{t('auth.verificationCode')}</Label>
                <div className="flex gap-2">
                  <div className="relative flex-1">
                    <ShieldCheck className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/60" />
                    <Input
                      id="reg-code"
                      type="text"
                      value={code}
                      onChange={(e) => setCode(e.target.value)}
                      placeholder={t('auth.codePlaceholder')}
                      maxLength={6}
                      required
                      className="pl-9"
                    />
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    disabled={codeSending || codeCooldown > 0}
                    onClick={handleSendCode}
                    className="w-28 shrink-0"
                  >
                    {codeSending ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : codeCooldown > 0 ? (
                      `${codeCooldown}s`
                    ) : (
                      t('auth.sendCode')
                    )}
                  </Button>
                </div>
              </div>

              {error && (
                <div className="flex items-start gap-2 rounded-lg border border-destructive/30 bg-danger-surface px-3 py-2.5 animate-in fade-in duration-200">
                  <AlertCircle className="mt-0.5 h-4 w-4 shrink-0 text-destructive" />
                  <p className="text-sm font-medium text-destructive">{formatUiMessage(error, t)}</p>
                </div>
              )}

              <Button type="submit" disabled={loading} size="lg" className="w-full">
                {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : t('auth.register')}
              </Button>
            </form>

            <p className="mt-6 text-center text-sm text-muted-foreground">
              {t('auth.haveAccount')}{' '}
              <Link href="/login" className="font-medium text-primary underline-offset-4 hover:underline">
                {t('auth.goToLogin')}
              </Link>
            </p>

            <LegalDocLinks className="mt-4 border-t border-border/50 pt-4" />
          </CardContent>
        </Card>
        </section>

        <AuthDownloadPanel />
      </div>

      <SiteFooter />
    </div>
  );
}
