'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState, useEffect, useRef, useCallback } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useI18n } from '@/contexts/I18nContext';
import { BrandLogo } from '@/components/brand/BrandLogo';
import { formatUiMessage } from '@/lib/uiMessage';
import { logger } from '@/lib/logger';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent } from '@/components/ui/card';
import { QRCodeSVG } from 'qrcode.react';
import { createQrSession, getQrStatus } from '@/lib/api/auth';
import { saveTokens } from '@/lib/api/client';
import { analyticsTrack } from '@/lib/analytics';
import { AnalyticsEvents } from '@/lib/analyticsEvents';
import {
  Mail,
  Lock,
  Eye,
  EyeOff,
  AlertCircle,
  QrCode,
  Loader2,
  ArrowLeft,
  CheckCircle2,
  KeyRound,
  ShieldCheck,
} from 'lucide-react';
import { LegalDocLinks } from '@/components/auth/legal-doc-links';

const TAG = 'login-card';

type LoginMode = 'password' | 'qr';
type QrState = 'loading' | 'pending' | 'scanned' | 'confirmed' | 'expired' | 'error';

function getPostAuthRedirect(): string {
  if (typeof window === 'undefined') return '/chat';
  const next = new URLSearchParams(window.location.search).get('next')?.trim();
  if (next && next.startsWith('/') && !next.startsWith('//')) return next;
  return '/chat';
}

export function LoginAuthCard() {
  const router = useRouter();
  const { t } = useI18n();
  const { login, setAuthFromTokens } = useAuth();
  const [mode, setMode] = useState<LoginMode>('qr');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  const [qrState, setQrState] = useState<QrState>('loading');
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [qrErrorDetail, setQrErrorDetail] = useState<string | null>(null);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const stopPolling = useCallback(() => {
    if (pollRef.current) {
      clearInterval(pollRef.current);
      pollRef.current = null;
    }
  }, []);

  const startQrSession = useCallback(async () => {
    stopPolling();
    setQrState('loading');
    setSessionId(null);
    setQrErrorDetail(null);
    try {
      const sid = await createQrSession();
      setSessionId(sid);
      setQrState('pending');

      pollRef.current = setInterval(async () => {
        try {
          const res = await getQrStatus(sid);
          if (res.status === 'SCANNED') {
            setQrState('scanned');
          } else if (res.status === 'CONFIRMED' && res.accessToken && res.refreshToken && res.userId) {
            stopPolling();
            setQrState('confirmed');
            const authData = {
              accessToken: res.accessToken,
              refreshToken: res.refreshToken,
              userId: res.userId,
              expiresIn: res.expiresIn ?? 0,
            };
            saveTokens(authData);
            setAuthFromTokens(authData);
            logger.info(TAG, 'qr login success userId=', res.userId);
            analyticsTrack(AnalyticsEvents.qrLoginOutcome, {
              side: 'display',
              status: 'confirmed',
            });
            router.push(getPostAuthRedirect());
            router.refresh();
          } else if (res.status === 'EXPIRED' || res.status === 'CANCELLED') {
            stopPolling();
            setQrState('expired');
            analyticsTrack(AnalyticsEvents.qrLoginOutcome, {
              side: 'display',
              status: 'expired',
            });
          }
        } catch (e) {
          stopPolling();
          const msg = e instanceof Error ? e.message : 'auth.queryStatusFailed';
          setQrErrorDetail(msg);
          setQrState('error');
          logger.warn(TAG, 'qr poll failed', msg);
          analyticsTrack(AnalyticsEvents.qrLoginOutcome, {
            side: 'display',
            status: 'error',
            stage: 'poll',
          });
        }
      }, 2000);
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'auth.createQrFailed';
      setQrErrorDetail(msg);
      setQrState('error');
      logger.warn(TAG, 'createQrSession UI catch', msg);
      analyticsTrack(AnalyticsEvents.qrLoginOutcome, {
        side: 'display',
        status: 'error',
        stage: 'create_session',
      });
    }
  }, [stopPolling, router, setAuthFromTokens]);

  useEffect(() => {
    if (mode === 'qr') {
      startQrSession();
    } else {
      stopPolling();
      setQrErrorDetail(null);
    }
    return stopPolling;
  }, [mode, startQrSession, stopPolling]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    logger.info(TAG, 'submit login email=', email.trim());
    try {
      await login(email, password);
      const redirectTo = getPostAuthRedirect();
      logger.info(TAG, 'submit success redirect to ', redirectTo);
      router.push(redirectTo);
      router.refresh();
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'auth.requestFailed';
      logger.warn(TAG, 'submit failed', msg);
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  const qrStatusText: Record<QrState, string> = {
    loading: t('auth.qrLoading'),
    pending: t('auth.qrPending'),
    scanned: t('auth.qrScanned'),
    confirmed: t('auth.qrConfirmed'),
    expired: t('auth.qrExpired'),
    error: t('auth.qrError'),
  };

  return (
    <Card className="border-border/80 bg-card/92 shadow-xl shadow-black/10 backdrop-blur-xl ring-1 ring-border/45 dark:shadow-black/35 motion-safe:animate-app-fade-up app-stagger-2">
      <CardContent className="pt-6 sm:pt-7">
        <div className="mb-6 flex flex-col items-center text-center">
          <BrandLogo
            size={56}
            alt={t('auth.brandAlt')}
            className="shadow-lg ring-1 ring-black/5 dark:ring-white/10"
            priority
          />
          <h2 className="font-display mt-3 text-xl font-semibold tracking-tight">{t('common.brandName')}</h2>
          <p className="mt-1.5 max-w-sm text-sm text-muted-foreground">
            {mode === 'qr' ? t('auth.cardSubtitleQr') : t('auth.cardTitleLogin')}
          </p>
        </div>

        {mode === 'password' ? (
          <>
            <form onSubmit={submit} className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="login-email">{t('auth.email')}</Label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/60" />
                  <Input
                    id="login-email"
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
                <Label htmlFor="login-password">{t('auth.password')}</Label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/60" />
                  <Input
                    id="login-password"
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

              {error && (
                <div className="flex items-start gap-2 rounded-lg border border-destructive/30 bg-danger-surface px-3 py-2.5 animate-in fade-in duration-200">
                  <AlertCircle className="mt-0.5 h-4 w-4 shrink-0 text-destructive" />
                  <p className="text-sm font-medium text-destructive">{formatUiMessage(error, t)}</p>
                </div>
              )}

              <Button type="submit" disabled={loading} size="lg" className="w-full">
                {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : t('auth.login')}
              </Button>
            </form>

            <p className="mt-5 text-center text-sm text-muted-foreground">
              {t('auth.noAccountYet')}{' '}
              <Link href="/register" className="font-medium text-primary underline-offset-4 hover:underline">
                {t('auth.goToRegister')}
              </Link>
            </p>

            <div className="relative my-5">
              <div className="absolute inset-0 flex items-center">
                <span className="w-full border-t" />
              </div>
              <div className="relative flex justify-center text-xs">
                <span className="bg-card px-3 text-muted-foreground">{t('common.or')}</span>
              </div>
            </div>

            <Button variant="outline" onClick={() => { setMode('qr'); setError(''); }} className="w-full gap-2">
              <QrCode className="h-4 w-4" />
              {t('auth.scanLogin')}
            </Button>
          </>
        ) : (
          <div className="flex flex-col items-stretch space-y-5 py-1">
            <div className="flex items-center justify-between gap-2">
              <span className="text-sm font-semibold">{t('auth.scanLogin')}</span>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="h-8 gap-1.5 text-muted-foreground hover:text-foreground"
                onClick={() => setMode('password')}
              >
                <KeyRound className="h-4 w-4" />
                {t('auth.useEmailPassword')}
              </Button>
            </div>

            <div className="flex flex-col items-center gap-4">
              {qrState === 'loading' ? (
                <div className="flex h-[220px] w-[220px] items-center justify-center rounded-2xl border bg-muted/40">
                  <Loader2 className="h-9 w-9 animate-spin text-muted-foreground" />
                </div>
              ) : sessionId && (qrState === 'pending' || qrState === 'scanned') ? (
                <div className="relative rounded-2xl border bg-background p-4 shadow-sm ring-1 ring-border/80">
                  <QRCodeSVG
                    value={`ultrasend://qr-login/${sessionId}`}
                    size={256}
                    level="M"
                    includeMargin
                    className="rounded-lg"
                  />
                  {qrState === 'scanned' && (
                    <div className="absolute inset-0 flex items-center justify-center rounded-lg bg-background/90 backdrop-blur-sm">
                      <div className="flex flex-col items-center gap-2 px-4 text-center">
                        <div className="flex h-10 w-10 items-center justify-center rounded-full bg-primary/15">
                          <ShieldCheck className="h-5 w-5 text-primary" />
                        </div>
                        <p className="text-sm font-medium leading-snug">
                          {t('auth.scannedTitle')}
                          <br />
                          {t('auth.scannedSub')}
                        </p>
                      </div>
                    </div>
                  )}
                </div>
              ) : (
                <div className="flex h-[220px] w-[220px] flex-col items-center justify-center gap-3 rounded-2xl border border-dashed bg-muted/30 px-4 text-center">
                  {qrState === 'confirmed' ? (
                    <CheckCircle2 className="h-10 w-10 text-primary/80" />
                  ) : (
                    <AlertCircle className="h-10 w-10 text-muted-foreground/50" />
                  )}
                </div>
              )}

              <p
                className={cn(
                  'min-h-5 px-1 text-center text-sm leading-snug',
                  qrState === 'error' && qrErrorDetail ? 'font-medium text-destructive' : 'text-muted-foreground',
                )}
              >
                {qrState === 'error' && qrErrorDetail ? qrErrorDetail : qrStatusText[qrState]}
              </p>

              {(qrState === 'expired' || qrState === 'error') && (
                <Button variant="outline" size="sm" onClick={startQrSession} className="w-full max-w-xs">
                  {t('auth.refreshQr')}
                </Button>
              )}
            </div>

            <p className="text-center text-xs text-muted-foreground">
              {t('auth.noAccountYet')}{' '}
              <Link href="/register" className="font-medium text-primary underline-offset-4 hover:underline">
                {t('auth.goToRegister')}
              </Link>
            </p>
          </div>
        )}

        <LegalDocLinks className="mt-5 border-t border-border/50 pt-4" />
      </CardContent>
    </Card>
  );
}
