'use client';

import { useMemo } from 'react';
import type { DeviceDto } from '@/lib/api';
import { useI18n, type TranslateFn } from '@/contexts/I18nContext';
import { collatorForLocaleTag } from '@/lib/i18nCollator';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Checkbox } from '@/components/ui/checkbox';
import { Button } from '@/components/ui/button';
import { PlatformIcon } from './PlatformIcon';
import { formatDisplayCodeChipLabel } from '@/lib/displayCode';
import { cn } from '@/lib/utils';
import type { ReachStatus } from '@/hooks/useSendTargetProbes';
import type { WebSendMode } from '@/lib/sendTargetStorage';
import { PanelLeftClose, RefreshCw } from 'lucide-react';
import { VirtualizedDeviceRows } from '@/components/devices/VirtualizedDeviceRows';

function renderStatusBadge(status: ReachStatus, mode: 'webrtc' | 'lan', t: TranslateFn) {
  if (status === 'checking') {
    return (
      <span className="inline-flex items-center gap-1 text-muted-foreground">
        <span className="inline-block w-2.5 h-2.5 border border-current border-t-transparent rounded-full animate-spin" />
        <span>{t('sendPanel.probing')}</span>
      </span>
    );
  }
  if (status === 'online') {
    return (
      <span className="text-emerald-500">
        {mode === 'webrtc' ? t('sendPanel.onlineWebrtc') : t('sendPanel.onlineLan')}
      </span>
    );
  }
  return <span className="text-muted-foreground">{t('sendPanel.offline')}</span>;
}

export function DeviceSendPanel({
  devices,
  currentDeviceId,
  sendMode,
  onSendModeChange,
  selectedTargets,
  onToggleTarget,
  webrtcReach,
  lanReach,
  onRefreshTargets,
  targetsProbing,
  className,
  showCollapseButton,
  onCollapseSidebar,
}: {
  devices: DeviceDto[];
  currentDeviceId: string;
  sendMode: WebSendMode;
  onSendModeChange: (m: WebSendMode) => void;
  selectedTargets: Set<string>;
  onToggleTarget: (deviceId: string) => void;
  webrtcReach: Record<string, ReachStatus>;
  lanReach: Record<string, ReachStatus>;
  /** 刷新设备列表并重新检测 HTTP/WebRTC 在线状态 */
  onRefreshTargets: () => void;
  targetsProbing: boolean;
  className?: string;
  showCollapseButton?: boolean;
  onCollapseSidebar?: () => void;
}) {
  const { t, localeTag } = useI18n();
  const nameCollator = useMemo(() => collatorForLocaleTag(localeTag), [localeTag]);
  const webrtcAvailable = typeof window !== 'undefined' && window.isSecureContext;

  const registeredIds = useMemo(
    () => new Set(devices.map((d) => d.deviceId)),
    [devices],
  );

  const otherDevices = useMemo(
    () => devices.filter((d) => d.deviceId !== currentDeviceId),
    [devices, currentDeviceId],
  );

  const lanDevices = useMemo(
    () => otherDevices.filter((d) => d.platform !== 'web'),
    [otherDevices],
  );

  const reachPriority = (s: string) => (s === 'online' ? 0 : 1);

  const sortedWebrtc = useMemo(
    () => [...otherDevices].sort((a, b) => {
      const aMine = registeredIds.has(a.deviceId);
      const bMine = registeredIds.has(b.deviceId);
      if (aMine !== bMine) return aMine ? -1 : 1;
      const byReach =
        reachPriority(webrtcReach[a.deviceId] ?? 'offline') -
        reachPriority(webrtcReach[b.deviceId] ?? 'offline');
      if (byReach !== 0) return byReach;
      return nameCollator.compare(a.name, b.name);
    }),
    [otherDevices, webrtcReach, registeredIds, nameCollator],
  );
  const sortedLan = useMemo(
    () => [...lanDevices].sort((a, b) => {
      const aMine = registeredIds.has(a.deviceId);
      const bMine = registeredIds.has(b.deviceId);
      if (aMine !== bMine) return aMine ? -1 : 1;
      const byReach =
        reachPriority(lanReach[a.deviceId] ?? 'offline') -
        reachPriority(lanReach[b.deviceId] ?? 'offline');
      if (byReach !== 0) return byReach;
      return nameCollator.compare(a.name, b.name);
    }),
    [lanDevices, lanReach, registeredIds, nameCollator],
  );

  const tabValue = sendMode === 'webrtc' && !webrtcAvailable ? 'lan' : sendMode;

  function renderDeviceRow(
    d: DeviceDto,
    statusMap: Record<string, ReachStatus>,
    mode: 'webrtc' | 'lan',
  ) {
    const codeLabel = d.displayCode != null ? formatDisplayCodeChipLabel(d.displayCode) : null;
    const status = statusMap[d.deviceId] ?? 'checking';
    const canSelect = status === 'online';
    const supportsResume = d.platform !== 'web';
    const isMyDevice = registeredIds.has(d.deviceId);
    return (
      <label
        className={cn(
          'flex items-center gap-2 rounded-xl px-2 py-2 transition-colors duration-150',
          canSelect ? 'cursor-pointer hover:bg-muted/55' : 'cursor-not-allowed opacity-60',
        )}
      >
        <Checkbox
          checked={selectedTargets.has(d.deviceId)}
          onCheckedChange={() => {
            if (canSelect) onToggleTarget(d.deviceId);
          }}
          disabled={!canSelect}
        />
        <div className="w-7 shrink-0 flex items-center justify-center">
          <PlatformIcon platform={d.platform} size={18} />
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-x-1.5 gap-y-0.5 min-w-0">
            <span className={cn('text-sm truncate', canSelect && 'font-medium')}>{d.name}</span>
            <span
              className={cn(
                'shrink-0 rounded px-1.5 py-0 text-[10px] font-semibold leading-tight',
                isMyDevice
                  ? 'bg-muted/80 text-muted-foreground'
                  : 'bg-amber-500/15 text-amber-800 dark:text-amber-400',
              )}
            >
              {isMyDevice ? t('sendPanel.myDevice') : t('sendPanel.external')}
            </span>
            {codeLabel != null && (
              <span className="text-xs text-muted-foreground shrink-0" title={`设备号 ${d.displayCode}`}>
                ({codeLabel})
              </span>
            )}
          </div>
          <div className="text-[10px] mt-0.5">
            {renderStatusBadge(status, mode, t)}
            {canSelect && (
              <>
                <span className="text-muted-foreground"> · </span>
                {mode === 'webrtc' ? (
                  supportsResume ? (
                    <span className="text-emerald-400">{t('sendPanel.resumeOk')}</span>
                  ) : (
                    <span className="text-red-400">{t('sendPanel.resumeNo')}</span>
                  )
                ) : (
                  <span className="text-emerald-400">{t('sendPanel.resumeOk')}</span>
                )}
              </>
            )}
          </div>
        </div>
      </label>
    );
  }

  const renderDeviceList = (
    deviceList: DeviceDto[],
    statusMap: Record<string, ReachStatus>,
    mode: 'webrtc' | 'lan',
  ) => {
    if (deviceList.length === 0) {
      return (
        <p className="text-xs text-muted-foreground py-3 px-1">
          {mode === 'lan'
            ? t('sendPanel.noHttpTargets')
            : t('sendPanel.noOtherDevices')}
        </p>
      );
    }
    return (
      <VirtualizedDeviceRows
        count={deviceList.length}
        estimateRowHeight={84}
        getItemKey={(i) => deviceList[i]!.deviceId}
        className="flex-1 min-h-0 overflow-y-auto overscroll-contain px-1 py-1 pr-2"
        renderRow={(i) => renderDeviceRow(deviceList[i]!, statusMap, mode)}
      />
    );
  };

  return (
    <div
      className={cn(
        'flex h-full min-h-0 flex-col bg-card',
        className,
      )}
    >
      <div className="flex shrink-0 items-center justify-between gap-1 border-b border-border/50 bg-muted/25 px-2.5 py-2">
        <span className="font-display truncate text-xs font-semibold tracking-tight">{t('sendPanel.title')}</span>
        <div className="flex shrink-0 items-center gap-0.5">
          <Button
            type="button"
            variant="ghost"
            size="icon-sm"
            className="shrink-0"
            title={t('sendPanel.refreshTitle')}
            disabled={targetsProbing}
            onClick={onRefreshTargets}
          >
            <RefreshCw className={cn('h-4 w-4', targetsProbing && 'motion-safe:animate-spin')} />
          </Button>
          {showCollapseButton && onCollapseSidebar && (
            <Button
              type="button"
              variant="ghost"
              size="icon-sm"
              className="shrink-0"
              title={t('sendPanel.collapseTitle')}
              onClick={onCollapseSidebar}
            >
              <PanelLeftClose className="w-4 h-4" />
            </Button>
          )}
        </div>
      </div>

      <Tabs
        value={tabValue}
        onValueChange={(v) => onSendModeChange(v as WebSendMode)}
        className="flex flex-col flex-1 min-h-0 gap-0"
      >
        <TabsList
          className={cn(
            'flex h-auto w-full shrink-0 flex-wrap justify-start gap-0.5 rounded-none border-b border-border/50 bg-muted/20 p-1',
          )}
        >
          <TabsTrigger value="lan" className="text-xs px-2 py-1">
            HTTP
          </TabsTrigger>
          {webrtcAvailable && (
            <TabsTrigger value="webrtc" className="text-xs px-2 py-1">
              WebRTC
            </TabsTrigger>
          )}
          <TabsTrigger value="s3" className="text-xs px-2 py-1">
            S3
          </TabsTrigger>
        </TabsList>

        <div className="flex flex-col flex-1 min-h-0 min-w-0">
          {tabValue === 'lan' && (
            <div className="flex min-h-0 flex-1 flex-col">
              <p className="shrink-0 border-b border-border/50 px-2 py-1.5 text-[11px] text-muted-foreground">
                {t('sendPanel.httpHint')}
              </p>
              {renderDeviceList(sortedLan, lanReach, 'lan')}
            </div>
          )}
          {tabValue === 'webrtc' && webrtcAvailable && (
            <div className="flex min-h-0 flex-1 flex-col">
              <p className="shrink-0 border-b border-border/50 px-2 py-1.5 text-[11px] text-muted-foreground">
                {t('sendPanel.webrtcHint')}
              </p>
              {renderDeviceList(sortedWebrtc, webrtcReach, 'webrtc')}
            </div>
          )}
          {tabValue === 's3' && (
            <div className="flex flex-col shrink-0 px-2 py-2">
              <p className="text-[11px] text-muted-foreground">
                {t('sendPanel.s3Hint')}
              </p>
              <div className="inline-flex items-center gap-1 text-[11px] text-emerald-400 mt-2">
                <span>✓</span>
                <span>{t('sendPanel.resumeOk')}</span>
              </div>
            </div>
          )}
        </div>
      </Tabs>
    </div>
  );
}
