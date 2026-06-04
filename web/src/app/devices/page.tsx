'use client';

import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { useI18n } from '@/contexts/I18nContext';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { deleteDevice, listDevices, updateDevice, type DeviceDto } from '@/lib/api';
import { analyticsTrack } from '@/lib/analytics';
import { AnalyticsEvents } from '@/lib/analyticsEvents';
import { getOrCreateDeviceId, setDeviceName } from '@/lib/deviceId';
import { logger } from '@/lib/logger';
import { toast } from 'sonner';
import { DeviceListItem } from '@/components/devices/DeviceListItem';
import { VirtualizedDeviceRows } from '@/components/devices/VirtualizedDeviceRows';

const TAG = 'devices';

export default function DevicesPage() {
  const { t } = useI18n();
  const { accessToken, isReady } = useAuth();
  const router = useRouter();
  const [devices, setDevices] = useState<DeviceDto[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [editingName, setEditingName] = useState<string | null>(null);
  const [editValue, setEditValue] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!isReady) return;
    if (!accessToken) {
      router.push('/login');
      return;
    }
    setLoadError(null);
    setLoading(true);
    listDevices()
      .then((list) => {
        logger.info(TAG, 'listDevices success count=', list.length);
        setDevices(list);
      })
      .catch((e) => {
        logger.warn(TAG, 'listDevices failed', e);
        setDevices([]);
        setLoadError(t('devices.listLoadFailed'));
        toast.error(t('devices.toastLoadFailed'));
      })
      .finally(() => setLoading(false));
  }, [isReady, accessToken, router, t]);

  const currentDeviceId = typeof window !== 'undefined' ? getOrCreateDeviceId() : '';

  const startEdit = (d: DeviceDto) => {
    setEditingName(d.deviceId);
    setEditValue(d.name);
  };

  const removeDevice = async (d: DeviceDto) => {
    if (
      !window.confirm(t('devices.removeConfirm'))
    ) {
      return;
    }
    try {
      await deleteDevice(d.deviceId);
      setDevices((prev) => prev.filter((x) => x.deviceId !== d.deviceId));
      toast.success(t('devices.removed'));
      analyticsTrack(AnalyticsEvents.deviceRemove, { result: 'success' });
    } catch (e) {
      logger.warn(TAG, 'deleteDevice failed', e);
      toast.error(t('devices.removeFailed'));
      analyticsTrack(AnalyticsEvents.deviceRemove, { result: 'fail' });
    }
  };

  const saveName = async () => {
    if (!editingName || saving) return;
    const normalized = editValue.trim();
    if (!normalized) {
      toast.error(t('devices.nameEmpty'));
      return;
    }

    logger.info(TAG, 'saveName deviceId=', editingName, 'name=', editValue);
    setSaving(true);
    try {
      if (editingName === currentDeviceId) {
        setDeviceName(normalized);
        setDevices((prev) =>
          prev.map((d) => (d.deviceId === currentDeviceId ? { ...d, name: normalized } : d))
        );
        logger.info(TAG, 'saveName local device updated');
      } else {
        await updateDevice(editingName, { name: normalized });
        setDevices((prev) =>
          prev.map((d) => (d.deviceId === editingName ? { ...d, name: normalized } : d))
        );
        logger.info(TAG, 'saveName remote device updated');
      }
      toast.success(t('common.saved'));
    } catch (e) {
      logger.warn(TAG, 'saveName failed', e);
      toast.error(t('devices.saveFailed'));
    } finally {
      setSaving(false);
      setEditingName(null);
    }
  };

  if (!isReady) {
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
  if (!accessToken) return null;

  return (
    <div className="min-h-dvh p-4 text-foreground animate-app-fade-in">
      <div className="mx-auto max-w-lg">
        <div className="mb-6">
          <div className="flex items-center gap-4">
            <Link href="/chat" className="text-muted-foreground transition-colors hover:text-foreground">
              ← {t('common.back')}
            </Link>
            <h1 className="font-display text-xl font-semibold tracking-tight">{t('devices.myDevices')}</h1>
          </div>
          {!loading && <p className="text-sm text-muted-foreground mt-1">{t('devices.deviceCount', { count: devices.length })}</p>}
        </div>
        {loading ? (
          <div className="flex items-center gap-2 text-muted-foreground">
            <div className="animate-spin rounded-full h-5 w-5 border-2 border-primary border-t-transparent" />
            <span>{t('common.loading')}</span>
          </div>
        ) : (
          <>
            {loadError && (
              <p className="text-sm text-destructive rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 mb-3">
                {loadError}
              </p>
            )}
            {devices.length === 0 && !loadError && (
              <div className="rounded-2xl border border-dashed border-border/60 bg-muted/20 px-3 py-10 text-center text-sm text-muted-foreground backdrop-blur-sm">
                {t('devices.emptyRegistered')}
              </div>
            )}
            <VirtualizedDeviceRows
              count={devices.length}
              estimateRowHeight={112}
              className="max-h-[min(70dvh,560px)] overflow-y-auto rounded-xl"
              getItemKey={(i) => devices[i]!.deviceId}
              renderRow={(i) => (
                <DeviceListItem
                  asContainer="div"
                  device={devices[i]!}
                  currentDeviceId={currentDeviceId}
                  isEditing={editingName === devices[i]!.deviceId}
                  editValue={editValue}
                  onEditValueChange={setEditValue}
                  onStartEdit={startEdit}
                  onSaveEdit={saveName}
                  onRemove={removeDevice}
                />
              )}
            />
          </>
        )}
        <p className="text-xs text-muted-foreground mt-4">
          {t('devices.lanFileHint')}
        </p>
      </div>
    </div>
  );
}
