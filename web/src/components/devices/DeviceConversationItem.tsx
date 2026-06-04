'use client';

import { PlatformIcon } from '@/components/PlatformIcon';
import type { DeviceDto } from '@/lib/api';
import type { ReachStatus } from '@/hooks/useSendTargetProbes';
import { formatDisplayCodeChipLabel } from '@/lib/displayCode';
import { cn } from '@/lib/utils';
import { useI18n } from '@/contexts/I18nContext';

export function DeviceConversationItem({
  device,
  isMyDevice,
  selected,
  reachStatus,
  lastMessage,
  onClick,
}: {
  device: DeviceDto;
  /** 账号下已注册设备为「我的」，否则为「外部」（例如仅局域网发现）。 */
  isMyDevice: boolean;
  selected: boolean;
  reachStatus: ReachStatus;
  lastMessage?: string;
  onClick: () => void;
}) {
  const { t } = useI18n();
  const online = reachStatus === 'online';
  const checking = reachStatus === 'checking';

  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'flex w-full items-center gap-3 rounded-lg px-2.5 py-3 text-left transition-colors duration-150',
        selected ? 'item-selected-soft' : 'bg-card hover:bg-muted/60',
      )}
    >
      <div className="relative shrink-0">
        <div
          className={cn(
            'flex size-10 items-center justify-center rounded-lg transition-colors',
            selected ? 'bg-primary/12' : 'bg-muted/80',
          )}
        >
          <PlatformIcon platform={device.platform} size={22} />
        </div>
        <span
          className={cn(
            'absolute -bottom-0.5 -right-0.5 size-3 rounded-full border-2 border-card',
            online ? 'bg-emerald-500' : checking ? 'bg-amber-400' : 'bg-muted-foreground/40',
          )}
        />
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-center justify-between gap-2 min-w-0">
          <div className="flex min-w-0 flex-1 items-center gap-1.5">
            <span
              className={cn(
                'truncate text-sm min-w-0',
                selected ? 'font-semibold text-primary' : 'font-medium text-foreground',
              )}
            >
              {device.name}
            </span>
            <span
              className={cn(
                'shrink-0 rounded px-1.5 py-0 text-[10px] font-semibold leading-tight',
                isMyDevice
                  ? selected
                    ? 'bg-primary/12 text-primary'
                    : 'bg-muted/80 text-muted-foreground'
                  : selected
                    ? 'border border-primary/20 bg-primary/8 text-primary'
                    : 'bg-amber-500/15 text-amber-800 dark:text-amber-400',
              )}
            >
              {isMyDevice ? t('sendPanel.myDevice') : t('sendPanel.external')}
            </span>
          </div>
          {device.displayCode != null && (
            <span
              title={`设备号 ${device.displayCode}`}
              className={cn(
                'shrink-0 max-w-[42%] truncate rounded-md px-1.5 py-0 font-mono text-[10px] font-medium tabular-nums leading-tight',
                selected
                  ? 'border border-primary/20 bg-primary/8 text-primary'
                  : 'border border-border/70 bg-muted/50 text-muted-foreground',
              )}
            >
              {formatDisplayCodeChipLabel(device.displayCode)}
            </span>
          )}
        </div>
        {lastMessage && (
          <p className="mt-0.5 truncate text-xs text-muted-foreground">
            {lastMessage}
          </p>
        )}
        {!lastMessage && (
          <p
            className={cn(
              'mt-0.5 text-xs',
              selected ? 'text-muted-foreground' : 'text-text-tertiary',
            )}
          >
            {online ? t('chat.header.online') : checking ? t('chat.header.checking') : t('chat.header.offline')}
          </p>
        )}
      </div>
    </button>
  );
}
