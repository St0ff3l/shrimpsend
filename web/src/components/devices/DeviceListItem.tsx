'use client';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { PlatformIcon } from '@/components/PlatformIcon';
import type { DeviceDto } from '@/lib/api';
import { formatDisplayCodeChipLabel } from '@/lib/displayCode';
import { useI18n } from '@/contexts/I18nContext';

type DeviceListItemProps = {
  device: DeviceDto;
  currentDeviceId: string;
  isEditing: boolean;
  editValue: string;
  onEditValueChange: (value: string) => void;
  onStartEdit: (device: DeviceDto) => void;
  onSaveEdit: () => void;
  onRemove?: (device: DeviceDto) => void;
  className?: string;
  /** Use `div` when the parent virtual list row is already an `li`. */
  asContainer?: 'li' | 'div';
};

export function DeviceListItem({
  device,
  currentDeviceId,
  isEditing,
  editValue,
  onEditValueChange,
  onStartEdit,
  onSaveEdit,
  onRemove,
  className,
  asContainer = 'li',
}: DeviceListItemProps) {
  const { t } = useI18n();
  const containerClass =
    className ??
    'rounded-xl border border-border/60 bg-muted/35 p-3 shadow-sm ring-1 ring-foreground/3 backdrop-blur-sm transition-shadow duration-150 hover:shadow-md';
  const Container = asContainer === 'div' ? 'div' : 'li';
  return (
    <Container className={containerClass}>
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1 flex items-start gap-2.5">
          <PlatformIcon
            platform={device.platform}
            size={18}
            className="mt-0.5 shrink-0"
            aria-label={`platform-${device.platform ?? 'unknown'}`}
          />
          {isEditing ? (
            <Input
              type="text"
              value={editValue}
              onChange={(e) => onEditValueChange(e.target.value)}
              onBlur={onSaveEdit}
              onKeyDown={(e) => e.key === 'Enter' && onSaveEdit()}
              autoFocus
              className="flex-1"
            />
          ) : (
            <div className="min-w-0 flex-1">
              <div className="flex items-center justify-between gap-2">
                <div className="flex min-w-0 flex-1 items-center gap-2">
                  <p className="truncate text-sm font-semibold tracking-tight">{device.name}</p>
                  {device.deviceId === currentDeviceId && (
                    <Badge variant="default" className="shrink-0 text-[10px]">
                      {t('devices.currentDevice')}
                    </Badge>
                  )}
                </div>
                {device.displayCode != null && (
                  <span
                    title={`设备号 ${device.displayCode}`}
                    className="shrink-0 max-w-[45%] truncate rounded-md border border-border/70 bg-muted/50 px-1.5 py-0 font-mono text-[10px] font-medium tabular-nums leading-tight text-muted-foreground"
                  >
                    {formatDisplayCodeChipLabel(device.displayCode)}
                  </span>
                )}
              </div>
            </div>
          )}
        </div>

        {!isEditing && (
          <div className="flex shrink-0 items-center gap-1 pt-0.5">
            <Button variant="ghost" size="sm" onClick={() => onStartEdit(device)}>
              {t('devices.rename')}
            </Button>
            {onRemove && device.deviceId !== currentDeviceId && (
              <Button
                variant="ghost"
                size="sm"
                className="text-destructive hover:text-destructive"
                onClick={() => onRemove(device)}
              >
                {t('devices.remove')}
              </Button>
            )}
          </div>
        )}
      </div>
    </Container>
  );
}
