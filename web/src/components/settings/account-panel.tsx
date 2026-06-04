'use client';

import { useAuth } from '@/contexts/AuthContext';
import { useI18n } from '@/contexts/I18nContext';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import {
  fetchUserProfile,
  changePassword,
  sendChangePasswordCode,
  sendDeleteAccountCode,
  confirmDeleteAccount,
  type UserProfile,
} from '@/lib/api';
import { analyticsTrack } from '@/lib/analytics';
import { AnalyticsEvents } from '@/lib/analyticsEvents';
import { formatUiMessage } from '@/lib/uiMessage';
import { User } from 'lucide-react';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Alert, AlertDescription } from '@/components/ui/alert';
export type AccountPanelProps = {
  /** 关闭宿主（如弹层）；全屏设置页可省略。 */
  onClose?: () => void;
  /** 为 true 时不渲染底部「退出登录」（例如宽屏设置侧栏已有退出）。 */
  hideLogout?: boolean;
};

export function AccountPanel({ onClose, hideLogout = false }: AccountPanelProps) {
  const { t } = useI18n();
  const finishClose = onClose ?? (() => {});
  const { logout } = useAuth();
  const router = useRouter();
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [showChangePassword, setShowChangePassword] = useState(false);
  const [showDeleteAccount, setShowDeleteAccount] = useState(false);

  useEffect(() => {
    fetchUserProfile()
      .then(setProfile)
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const handleLogout = async () => {
    await logout();
    finishClose();
    router.push('/login');
  };

  return (
    <>
      <div className="space-y-5">
        {loading ? (
          <div className="flex items-center justify-center py-8">
            <div className="animate-spin rounded-full h-7 w-7 border-2 border-primary border-t-transparent" />
          </div>
        ) : (
          <>
            <div className="flex flex-col items-center gap-1.5 py-2">
              <span className="flex items-center justify-center w-[72px] h-[72px] rounded-full bg-primary/12 text-primary">
                <User className="w-9 h-9" />
              </span>
              <p className="text-base font-medium mt-1">{profile?.username || ''}</p>
              <p className="text-xs text-muted-foreground">{profile?.email || ''}</p>
            </div>

            <div className="flex flex-col gap-2 w-full">
              <Button type="button" variant="outline" className="w-full" onClick={() => setShowChangePassword(true)}>
                {t('account.changePassword')}
              </Button>
              <Button type="button" variant="ghost" className="w-full text-muted-foreground hover:text-muted-foreground" onClick={() => setShowDeleteAccount(true)}>
                {t('account.deleteAccount')}
              </Button>
              {!hideLogout && (
                <Button
                  type="button"
                  variant="outline"
                  className="w-full text-destructive border-destructive/34 hover:bg-destructive/5 hover:text-destructive"
                  onClick={handleLogout}
                >
                  {t('settings.logout')}
                </Button>
              )}
            </div>
          </>
        )}
      </div>

      <ChangePasswordDialog
        open={showChangePassword}
        onOpenChange={setShowChangePassword}
        email={profile?.email || ''}
      />
      <DeleteAccountDialog
        open={showDeleteAccount}
        onOpenChange={setShowDeleteAccount}
        email={profile?.email || ''}
        onClose={finishClose}
      />
    </>
  );
}

function ChangePasswordDialog({
  open,
  onOpenChange,
  email,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  email: string;
}) {
  const { t } = useI18n();
  const [code, setCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPwd, setConfirmPwd] = useState('');
  const [codeSending, setCodeSending] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [cooldown, setCooldown] = useState(0);
  const cooldownRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) {
      setCode('');
      setNewPassword('');
      setConfirmPwd('');
      setError(null);
      setCooldown(0);
      if (cooldownRef.current) {
        clearInterval(cooldownRef.current);
        cooldownRef.current = null;
      }
    }
  }, [open]);

  useEffect(() => {
    return () => {
      if (cooldownRef.current) clearInterval(cooldownRef.current);
    };
  }, []);

  const startCooldown = () => {
    setCooldown(60);
    if (cooldownRef.current) clearInterval(cooldownRef.current);
    cooldownRef.current = setInterval(() => {
      setCooldown((prev) => {
        if (prev <= 1) {
          if (cooldownRef.current) clearInterval(cooldownRef.current);
          cooldownRef.current = null;
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  };

  const handleSendCode = async () => {
    setCodeSending(true);
    setError(null);
    try {
      await sendChangePasswordCode();
      startCooldown();
    } catch (e) {
      setError(e instanceof Error ? e.message : t('account.errSendCodeFailed'));
    } finally {
      setCodeSending(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = code.trim();
    if (!trimmed) {
      setError(t('account.errEnterCode'));
      return;
    }
    if (!newPassword) {
      setError(t('account.errNeedNewPassword'));
      return;
    }
    if (newPassword.length < 6) {
      setError(t('account.errPasswordMin'));
      return;
    }
    if (newPassword !== confirmPwd) {
      setError(t('account.errPasswordMismatch'));
      return;
    }

    setSubmitting(true);
    setError(null);
    try {
      await changePassword(trimmed, newPassword);
      onOpenChange(false);
      analyticsTrack(AnalyticsEvents.settingChanged, {
        key: 'account_password',
        result: 'success',
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : t('account.errChangeFailed'));
      analyticsTrack(AnalyticsEvents.settingChanged, {
        key: 'account_password',
        result: 'fail',
      });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-[calc(100%-1.5rem)] px-4 py-5 sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t('account.dialogChangePasswordTitle')}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-3.5">
          <div>
            <p className="text-xs text-muted-foreground">{t('account.changePasswordHint')}</p>
            <p className="text-sm font-semibold mt-0.5">{email}</p>
          </div>
          {error && (
            <Alert variant="destructive">
              <AlertDescription>{formatUiMessage(error, t)}</AlertDescription>
            </Alert>
          )}
          <div className="flex gap-2 items-end">
            <div className="flex-1 space-y-1.5">
              <Label htmlFor="cp-code" className="text-xs">
                {t('account.verificationCode')}
              </Label>
              <Input
                id="cp-code"
                type="text"
                inputMode="numeric"
                maxLength={6}
                placeholder={t('auth.codePlaceholder')}
                value={code}
                onChange={(e) => setCode(e.target.value)}
              />
            </div>
            <Button
              type="button"
              size="default"
              disabled={codeSending || cooldown > 0}
              onClick={handleSendCode}
              className="shrink-0"
            >
              {codeSending ? t('account.sendCodeSending') : cooldown > 0 ? `${cooldown}s` : t('account.sendCodeButton')}
            </Button>
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="cp-new" className="text-xs">
              {t('account.newPassword')}
            </Label>
            <Input id="cp-new" type="password" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="cp-confirm" className="text-xs">
              {t('account.confirmNewPassword')}
            </Label>
            <Input id="cp-confirm" type="password" value={confirmPwd} onChange={(e) => setConfirmPwd(e.target.value)} />
          </div>
          <Button type="submit" className="w-full" disabled={submitting || !code.trim()}>
            {submitting ? t('account.submitting') : t('common.confirm')}
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function DeleteAccountDialog({
  open,
  onOpenChange,
  email,
  onClose,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  email: string;
  onClose: () => void;
}) {
  const { t } = useI18n();
  const { logout } = useAuth();
  const router = useRouter();
  const [code, setCode] = useState('');
  const [codeSending, setCodeSending] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [cooldown, setCooldown] = useState(0);
  const cooldownRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) {
      setCode('');
      setError(null);
      setCooldown(0);
      if (cooldownRef.current) {
        clearInterval(cooldownRef.current);
        cooldownRef.current = null;
      }
    }
  }, [open]);

  useEffect(() => {
    return () => {
      if (cooldownRef.current) clearInterval(cooldownRef.current);
    };
  }, []);

  const startCooldown = () => {
    setCooldown(60);
    if (cooldownRef.current) clearInterval(cooldownRef.current);
    cooldownRef.current = setInterval(() => {
      setCooldown((prev) => {
        if (prev <= 1) {
          if (cooldownRef.current) clearInterval(cooldownRef.current);
          cooldownRef.current = null;
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  };

  const handleSendCode = async () => {
    setCodeSending(true);
    setError(null);
    try {
      await sendDeleteAccountCode();
      startCooldown();
    } catch (e) {
      setError(e instanceof Error ? e.message : t('account.errSendCodeFailed'));
    } finally {
      setCodeSending(false);
    }
  };

  const handleConfirmDelete = async () => {
    const trimmed = code.trim();
    if (!trimmed) {
      setError(t('account.errEnterCode'));
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await confirmDeleteAccount(trimmed);
      await logout();
      onOpenChange(false);
      onClose();
      router.push('/login');
    } catch (e) {
      setError(e instanceof Error ? e.message : t('account.errDeleteFailed'));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>{t('account.dialogDeleteTitle')}</DialogTitle>
        </DialogHeader>
        <div className="space-y-3.5">
          <div>
            <p className="text-xs text-muted-foreground">{t('account.deleteWarning')}</p>
            <p className="text-sm font-semibold mt-0.5">{email}</p>
          </div>
          {error && (
            <Alert variant="destructive">
              <AlertDescription>{formatUiMessage(error, t)}</AlertDescription>
            </Alert>
          )}
          <div className="flex gap-2 items-end">
            <div className="flex-1 space-y-1.5">
              <Label htmlFor="da-code" className="text-xs">
                {t('account.verificationCode')}
              </Label>
              <Input
                id="da-code"
                type="text"
                inputMode="numeric"
                maxLength={6}
                placeholder={t('auth.codePlaceholder')}
                value={code}
                onChange={(e) => setCode(e.target.value)}
              />
            </div>
            <Button type="button" size="default" disabled={codeSending || cooldown > 0} onClick={handleSendCode} className="shrink-0">
              {codeSending ? t('account.sendCodeSending') : cooldown > 0 ? `${cooldown}s` : t('account.sendCodeButton')}
            </Button>
          </div>
          <Button variant="destructive" className="w-full" disabled={submitting || !code.trim()} onClick={handleConfirmDelete}>
            {submitting ? t('account.deleting') : t('account.permanentDelete')}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
