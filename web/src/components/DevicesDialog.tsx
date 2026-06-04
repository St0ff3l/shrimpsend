'use client';

import { useCallback, useEffect, useState } from 'react';
import { listDevices, updateDevice, type DeviceDto } from '@/lib/api';
import { getOrCreateDeviceId, setDeviceName } from '@/lib/deviceId';
import { logger } from '@/lib/logger';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { toast } from 'sonner';
import { DeviceListItem } from '@/components/devices/DeviceListItem';
import { VirtualizedDeviceRows } from '@/components/devices/VirtualizedDeviceRows';
import { useI18n } from '@/contexts/I18nContext';

const TAG = 'devices-dialog';

export function DevicesDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const [devices, setDevices] = useState<DeviceDto[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [editingName, setEditingName] = useState<string | null>(null);
  const [editValue, setEditValue] = useState('');
  const [saving, setSaving] = useState(false);

  const loadDevices = useCallback(async () => {
    setLoading(true);
    setLoadError(null);
    try {
      const list = await listDevices();
      logger.info(TAG, 'listDevices success count=', list.length);
      setDevices(list);
    } catch (e) {
      logger.warn(TAG, 'listDevices failed', e);
      setDevices([]);
      setLoadError(t('devices.listLoadFailed'));
      toast.error(t('devices.toastLoadFailed'));
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => {
    if (!open) return;
    loadDevices();
  }, [open, loadDevices]);

  const currentDeviceId = typeof window !== 'undefined' ? getOrCreateDeviceId() : '';

  const startEdit = (d: DeviceDto) => {
    setEditingName(d.deviceId);
    setEditValue(d.name);
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
      } else {
        await updateDevice(editingName, { name: normalized });
        setDevices((prev) =>
          prev.map((d) => (d.deviceId === editingName ? { ...d, name: normalized } : d))
        );
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

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="flex max-h-[80vh] max-w-md flex-col">
        <DialogHeader className="border-b border-border/50 pb-3">
          <DialogTitle>{t('devices.myDevices')}</DialogTitle>
        </DialogHeader>

        <div className="flex min-h-0 flex-1 flex-col space-y-2 overflow-hidden pt-1">
          {loading ? (
            <div className="flex items-center justify-center py-8">
              <div className="animate-spin rounded-full h-7 w-7 border-2 border-primary border-t-transparent" />
            </div>
          ) : (
            <>
              {loadError && (
                <p className="text-xs text-destructive rounded-md border border-destructive/30 bg-destructive/5 px-2 py-1">
                  {loadError}
                </p>
              )}
              {devices.length === 0 && !loadError && (
                <div className="rounded-xl border border-dashed px-3 py-6 text-center text-sm text-muted-foreground">
                  {t('devices.emptyRegistered')}
                </div>
              )}
              <VirtualizedDeviceRows
                count={devices.length}
                estimateRowHeight={108}
                className="min-h-[200px] max-h-[min(55dvh,420px)] flex-1 overflow-y-auto"
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
                  />
                )}
              />
              <p className="text-[11px] text-muted-foreground mt-4 leading-relaxed">
                {t('devices.lanFileHint')}
              </p>
            </>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
