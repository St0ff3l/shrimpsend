'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useChatContext, S3_VIRTUAL_DEVICE_ID } from '@/contexts/ChatContext';
import { useAuth } from '@/contexts/AuthContext';
import { useI18n } from '@/contexts/I18nContext';
import { PlatformIcon } from '@/components/PlatformIcon';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { formatDisplayCodeChipLabel } from '@/lib/displayCode';
import { cn } from '@/lib/utils';
import { deleteDevice, updateDevice } from '@/lib/api';
import { setDeviceName } from '@/lib/deviceId';
import { logger } from '@/lib/logger';
import { toast } from 'sonner';
import { ArrowLeft, Cloud, MessageSquareX, Settings, Trash2 } from 'lucide-react';
import type { ReachStatus } from '@/hooks/useSendTargetProbes';
import { getReachDisplayStatus } from '@/hooks/useSendTargetProbes';

const TAG = 'chat-header';

export function ChatHeader({
  onBack,
  showBackButton,
}: {
  onBack?: () => void;
  showBackButton?: boolean;
}) {
  const router = useRouter();
  const { t } = useI18n();
  const { accessToken, logout } = useAuth();
  const [sessionSettingsOpen, setSessionSettingsOpen] = useState(false);
  const [renameValue, setRenameValue] = useState('');
  const [renameSaving, setRenameSaving] = useState(false);
  const [clearingMessages, setClearingMessages] = useState(false);

  const {
    devices,
    selectedDeviceId,
    deviceReach,
    selectMode,
    selectedKeys,
    exitSelectMode,
    toggleSelectAllMessages,
    handleBulkDelete,
    clearCurrentThreadMessages,
    messages,
    s3Configured,
    s3Online,
    s3Checking,
    currentDeviceId,
    refreshDevices,
    setSelectedDeviceId,
    connected,
  } = useChatContext();

  const isS3 = selectedDeviceId === S3_VIRTUAL_DEVICE_ID;
  const device = isS3 ? null : devices.find((d) => d.deviceId === selectedDeviceId);

  useEffect(() => {
    if (sessionSettingsOpen && device) {
      setRenameValue(device.name);
    }
  }, [sessionSettingsOpen, device?.deviceId, device?.name]);

  const handleSessionDeviceRename = async () => {
    if (!selectedDeviceId || renameSaving) return;
    const normalized = renameValue.trim();
    if (!normalized) {
      toast.error(t('devices.nameEmpty'));
      return;
    }
    setRenameSaving(true);
    try {
      await updateDevice(selectedDeviceId, { name: normalized });
      if (selectedDeviceId === currentDeviceId) {
        setDeviceName(normalized);
      }
      refreshDevices();
      toast.success(t('common.saved'));
    } catch (e) {
      logger.warn(TAG, 'session device rename failed', e);
      toast.error(t('devices.saveFailed'));
    } finally {
      setRenameSaving(false);
    }
  };

  const handleSessionClearMessages = async () => {
    if (clearingMessages) return;
    if (!window.confirm(t('chat.header.sessionClearMessagesConfirm'))) return;
    setClearingMessages(true);
    try {
      await clearCurrentThreadMessages();
      toast.success(t('chat.header.sessionClearMessagesDone'));
    } catch (e) {
      logger.warn(TAG, 'session clear messages failed', e);
      toast.error(t('chat.header.sessionClearMessagesFailed'));
    } finally {
      setClearingMessages(false);
    }
  };

  const handleSessionDeviceRemove = async () => {
    if (!selectedDeviceId) return;
    const isSelf = selectedDeviceId === currentDeviceId;
    const ok = window.confirm(isSelf ? t('chat.header.removeSelfConfirm') : t('devices.removeConfirm'));
    if (!ok) return;
    try {
      await deleteDevice(selectedDeviceId);
      setSessionSettingsOpen(false);
      if (isSelf) {
        await logout();
        toast.success(t('chat.header.toastRemovedSelf'));
        router.push('/login');
      } else {
        refreshDevices();
        setSelectedDeviceId(null);
        toast.success(t('devices.removed'));
      }
    } catch (e) {
      logger.warn(TAG, 'session device remove failed', e);
      toast.error(t('chat.header.operationFailed'));
    }
  };

  if (selectMode) {
    const allKeys = messages
      .map((m) => {
        if (m.id != null) return `id:${m.id}`;
        if (m._localId) return `local:${m._localId}`;
        return null;
      })
      .filter(Boolean) as string[];
    const allSelected = allKeys.length > 0 && allKeys.every((k) => selectedKeys.has(k));

    return (
      <div className="flex shrink-0 items-center justify-between gap-2 border-b border-border/60 bg-card px-3 py-2.5">
        <div className="flex items-center gap-1 min-w-0 flex-1">
          <Button variant="ghost" size="icon" className="shrink-0" onClick={exitSelectMode} title={t('chat.header.back')}>
            <ArrowLeft className="size-5" />
          </Button>
          <span className="font-display truncate text-base font-semibold tracking-tight">
            {t('chat.header.selectedCount', { count: selectedKeys.size })}
          </span>
        </div>
        <div className="flex items-center gap-0.5 shrink-0">
          <Button variant="ghost" size="sm" className="text-primary" onClick={toggleSelectAllMessages}>
            {allSelected ? t('chat.header.deselectAll') : t('chat.header.selectAll')}
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="text-destructive hover:text-destructive"
            disabled={selectedKeys.size === 0}
            title={t('chat.header.delete')}
            onClick={handleBulkDelete}
          >
            <Trash2 className="size-5" />
          </Button>
          <Button variant="ghost" size="sm" onClick={exitSelectMode}>
            {t('chat.header.cancel')}
          </Button>
        </div>
      </div>
    );
  }

  const reachStatus: ReachStatus = (() => {
    if (!selectedDeviceId) return 'offline';
    return getReachDisplayStatus(deviceReach[selectedDeviceId]);
  })();

  const s3DotClass = s3Checking
    ? 'bg-amber-400'
    : !s3Configured
      ? 'bg-muted-foreground/40'
      : s3Online
        ? 'bg-emerald-500'
        : 'bg-amber-400';

  const s3Subtitle = s3Checking
    ? t('deviceList.s3Checking')
    : !s3Configured
      ? t('deviceList.s3NotConfigured')
      : s3Online
        ? t('deviceList.s3OnlineAll')
        : t('deviceList.s3Unavailable');

  const showSessionDeviceSettings =
    !!accessToken && connected && !!device && !isS3 && !!selectedDeviceId;

  return (
    <>
      <div className="flex shrink-0 items-center gap-2 border-b border-border/60 bg-card px-3 py-2.5">
        {showBackButton && (
          <Button variant="ghost" size="icon" className="shrink-0" onClick={onBack} title={t('chat.header.backToDeviceList')}>
            <ArrowLeft className="size-5" />
          </Button>
        )}
        {isS3 ? (
          <>
            <div className="flex items-center gap-2.5 min-w-0 flex-1">
              <div className="relative shrink-0">
                <div className="flex size-9 items-center justify-center rounded-lg bg-sky-500/10">
                  <Cloud className="size-5 text-sky-500" />
                </div>
                <span
                  className={cn(
                    'absolute -bottom-0.5 -right-0.5 size-2.5 rounded-full border-2 border-card',
                    s3DotClass,
                  )}
                />
              </div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-semibold">{t('deviceList.s3RelayTitle')}</div>
                <div className="text-[11px] text-muted-foreground">{s3Subtitle}</div>
              </div>
            </div>
            <Button
              variant="ghost"
              size="icon"
              className="shrink-0"
              title={t('chat.header.s3SettingsTitle')}
              onClick={() => router.push('/settings/s3')}
            >
              <Settings className="size-5" />
            </Button>
          </>
        ) : device ? (
          <>
            <div className="flex items-center gap-2.5 min-w-0 flex-1">
              <div className="relative shrink-0">
                <div className="flex size-9 items-center justify-center rounded-lg bg-muted/80">
                  <PlatformIcon platform={device.platform} size={20} />
                </div>
                <span
                  className={cn(
                    'absolute -bottom-0.5 -right-0.5 size-2.5 rounded-full border-2 border-card',
                    reachStatus === 'online' ? 'bg-emerald-500' : reachStatus === 'checking' ? 'bg-amber-400' : 'bg-muted-foreground/40',
                  )}
                />
              </div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-semibold">{device.name}</div>
                <div className="mt-0.5 flex min-w-0 flex-wrap items-center gap-1.5">
                  {device.displayCode != null && (
                    <span
                      title={`${t('chat.header.deviceNumber')} ${device.displayCode}`}
                      className="shrink-0 rounded-md border border-border/70 bg-muted/50 px-1.5 py-0 font-mono text-[10px] font-semibold tabular-nums leading-tight text-muted-foreground"
                    >
                      {formatDisplayCodeChipLabel(device.displayCode)}
                    </span>
                  )}
                  <span className="min-w-0 truncate text-[11px] text-muted-foreground">
                    {reachStatus === 'online'
                      ? t('chat.header.online')
                      : reachStatus === 'checking'
                        ? t('chat.header.checking')
                        : t('chat.header.offline')}
                  </span>
                </div>
              </div>
            </div>
            {showSessionDeviceSettings && (
              <Button
                variant="ghost"
                size="icon"
                className="shrink-0"
                title={t('chat.header.sessionSettingsTitle')}
                onClick={() => setSessionSettingsOpen(true)}
              >
                <Settings className="size-5" />
              </Button>
            )}
          </>
        ) : (
          <div className="flex-1 text-sm text-muted-foreground">{t('chat.header.pickDeviceHint')}</div>
        )}
      </div>

      <Dialog open={sessionSettingsOpen} onOpenChange={setSessionSettingsOpen}>
        <DialogContent showCloseButton className="max-w-sm gap-0 overflow-hidden p-0">
          <div className="border-b border-border/50 px-5 pb-3 pt-4 pr-12">
            <DialogHeader className="gap-0">
              <DialogTitle>{t('chat.header.sessionSettingsTitle')}</DialogTitle>
            </DialogHeader>
          </div>
          <div className="space-y-4 px-5 pb-5 pt-3">
            <div className="space-y-2">
              <label className="text-xs font-medium text-muted-foreground" htmlFor="session-device-name">
                {t('chat.header.sessionRenameLabel')}
              </label>
              <div className="flex gap-2">
                <Input
                  id="session-device-name"
                  value={renameValue}
                  onChange={(e) => setRenameValue(e.target.value)}
                  disabled={renameSaving}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') void handleSessionDeviceRename();
                  }}
                />
                <Button
                  type="button"
                  variant="secondary"
                  className="shrink-0"
                  disabled={renameSaving}
                  onClick={() => void handleSessionDeviceRename()}
                >
                  {t('common.save')}
                </Button>
              </div>
            </div>
            <Button
              variant="outline"
              className="w-full"
              disabled={clearingMessages}
              onClick={() => void handleSessionClearMessages()}
            >
              <MessageSquareX className="size-4" />
              {t('chat.header.sessionClearMessages')}
            </Button>
            <div className="space-y-2 border-t border-border/50 pt-3">
              <p className="text-xs text-muted-foreground leading-relaxed">
                {selectedDeviceId === currentDeviceId
                  ? t('chat.header.sessionRemoveSelfHint')
                  : t('chat.header.sessionRemoveOtherHint')}
              </p>
              <Button
                variant="destructive"
                className="w-full"
                onClick={() => void handleSessionDeviceRemove()}
              >
                {selectedDeviceId === currentDeviceId ? t('chat.header.deleteThisDevice') : t('chat.header.removeDevice')}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}
