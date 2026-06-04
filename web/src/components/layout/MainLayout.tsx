'use client';

import { useState } from 'react';
import { useDeviceListPanelWidth } from '@/hooks/useDeviceListPanelWidth';
import { useMinWidthMd } from '@/hooks/useMediaQuery';
import { useChatContext } from '@/contexts/ChatContext';
import { openClientReleaseDownload } from '@/lib/clientReleaseDownload';
import { openInNewTab } from '@/lib/openInNewTab';
import { DeviceListPanel } from './DeviceListPanel';
import { ChatDetailPanel } from './ChatDetailPanel';
import { DevicesDialog } from '@/components/DevicesDialog';
import { cn } from '@/lib/utils';

const openSettingsInNewTab = () => openInNewTab('/settings');

export function MainLayout() {
  const isWide = useMinWidthMd();
  const deviceListWidth = useDeviceListPanelWidth();
  const { selectedDeviceId, setSelectedDeviceId } = useChatContext();
  const [showDevices, setShowDevices] = useState(false);

  const handleBackToList = () => {
    setSelectedDeviceId(null);
  };

  if (isWide) {
    return (
      <>
        <div className="flex h-screen flex-row text-foreground animate-app-fade-in">
          <div
            className="shrink-0"
            style={{ width: deviceListWidth }}
          >
            <DeviceListPanel
              onShowSettings={openSettingsInNewTab}
              onShowDownload={openClientReleaseDownload}
            />
          </div>
          <ChatDetailPanel className="border-l border-border/60" />
        </div>
        <DevicesDialog open={showDevices} onOpenChange={setShowDevices} />
      </>
    );
  }

  // Narrow screen: single panel view
  return (
    <>
      <div
        className={cn(
          'flex h-dvh flex-col text-foreground animate-app-fade-in',
          selectedDeviceId ? 'bg-card' : 'bg-background',
        )}
      >
        {selectedDeviceId ? (
          <ChatDetailPanel
            showBackButton
            onBack={handleBackToList}
          />
        ) : (
          <DeviceListPanel
            onShowSettings={openSettingsInNewTab}
            onShowDownload={openClientReleaseDownload}
          />
        )}
      </div>
      <DevicesDialog open={showDevices} onOpenChange={setShowDevices} />
    </>
  );
}
