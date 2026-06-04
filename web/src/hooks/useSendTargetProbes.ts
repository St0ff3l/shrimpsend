'use client';

import { useCallback, useEffect, useMemo, useRef, useState, type MutableRefObject } from 'react';
import type { DeviceDto } from '@/lib/api';
import { logger } from '@/lib/logger';

const TAG = 'useSendTargetProbes';

/** UI display status (checking is probe progress, not device state). */
export type ReachStatus = 'checking' | 'online' | 'offline';

export type DeviceReachDetail = {
  directHttp: boolean;
  lanSignaling: boolean;
  webrtc: boolean;
};

export type DeviceReachEntry = {
  methods: DeviceReachDetail;
  probing: boolean;
};

const offlineMethods: DeviceReachDetail = { directHttp: false, lanSignaling: false, webrtc: false };
const offlineEntry: DeviceReachEntry = { methods: offlineMethods, probing: false };

export function isReachOnline(entry?: DeviceReachEntry): boolean {
  const m = entry?.methods;
  return !!(m?.directHttp || m?.lanSignaling || m?.webrtc);
}

export function getReachDisplayStatus(entry?: DeviceReachEntry): ReachStatus {
  if (isReachOnline(entry)) return 'online';
  if (entry?.probing) return 'checking';
  return 'offline';
}

export function reachSortPriority(entry?: DeviceReachEntry): number {
  return isReachOnline(entry) ? 0 : 1;
}

function initialReachEntry(): DeviceReachEntry {
  return offlineEntry;
}

function toProbingEntry(prev?: DeviceReachEntry): DeviceReachEntry {
  return {
    methods: prev?.methods ?? offlineMethods,
    probing: true,
  };
}

function toResolvedEntry(methods: DeviceReachDetail): DeviceReachEntry {
  return { methods, probing: false };
}

function buildFromDevicePresence(devices: DeviceDto[]): Record<string, DeviceReachEntry> {
  const m: Record<string, DeviceReachEntry> = {};
  for (const device of devices) m[device.deviceId] = initialReachEntry();
  return m;
}

function mergeReachOnListChange(
  prev: Record<string, DeviceReachEntry>,
  devices: DeviceDto[],
  connected: boolean,
): Record<string, DeviceReachEntry> {
  if (!connected) return buildFromDevicePresence(devices);
  const next: Record<string, DeviceReachEntry> = {};
  for (const device of devices) {
    next[device.deviceId] = device.presenceStatus === 'offline'
      ? offlineEntry
      : (prev[device.deviceId] ?? offlineEntry);
  }
  return next;
}

/** Probe all methods in parallel and return per-method results. */
async function probeDeviceAllMethods(
  device: DeviceDto,
  onDirectHttpProbe: (url: string) => Promise<boolean>,
  onLanHttpProbe: (deviceId: string) => Promise<{ success: boolean; lanHttpUrl?: string; senderReachable?: boolean }>,
  onWebRTCProbe: (deviceId: string) => Promise<boolean>,
): Promise<{ methods: DeviceReachDetail; freshLanUrl?: string }> {
  const results = await Promise.allSettled([
    // Direct HTTP probe
    (async () => {
      const lanUrl = device.lanHttpUrl;
      if (!lanUrl) return { ok: false, url: undefined };
      const ok = await onDirectHttpProbe(lanUrl);
      return { ok, url: ok ? lanUrl : undefined };
    })(),
    // LAN signaling probe
    (async () => {
      const result = await onLanHttpProbe(device.deviceId);
      return { ok: result.success, url: result.lanHttpUrl };
    })(),
    // WebRTC probe
    onWebRTCProbe(device.deviceId),
  ]);

  const directResult = results[0].status === 'fulfilled' ? results[0].value : { ok: false, url: undefined };
  const lanResult = results[1].status === 'fulfilled' ? results[1].value : { ok: false, url: undefined };
  const webrtcOk = results[2].status === 'fulfilled' ? results[2].value : false;

  const freshLanUrl = directResult.url ?? lanResult.url;

  return {
    methods: {
      directHttp: directResult.ok,
      lanSignaling: lanResult.ok,
      webrtc: webrtcOk,
    },
    freshLanUrl,
  };
}

export function useSendTargetProbes(
  otherDevices: DeviceDto[],
  lanDevices: DeviceDto[],
  connected: boolean,
  probeToken: number,
  onWebRTCProbe: (targetDeviceId: string) => Promise<boolean>,
  onLanHttpProbe: (
    targetDeviceId: string,
  ) => Promise<{ success: boolean; lanHttpUrl?: string; senderReachable?: boolean }>,
  onDirectHttpProbe: (url: string) => Promise<boolean>,
): {
  deviceReach: Record<string, DeviceReachEntry>;
  freshLanUrlsRef: MutableRefObject<Record<string, string>>;
  probing: boolean;
  probeSingleDevice: (deviceId: string) => void;
} {
  const deviceFingerprint = useMemo(
    () =>
      otherDevices
        .map(
          (d) =>
            `${d.deviceId}:${d.presenceStatus ?? ''}:${d.presenceUpdatedAt ?? ''}:${d.lanHttpUrl ?? ''}`,
        )
        .join(','),
    [otherDevices],
  );

  const [deviceReach, setDeviceReach] = useState<Record<string, DeviceReachEntry>>(() =>
    buildFromDevicePresence(otherDevices),
  );
  const [probing, setProbing] = useState(false);

  const freshLanUrlsRef = useRef<Record<string, string>>({});
  const deviceSnapshotRef = useRef(otherDevices);
  deviceSnapshotRef.current = otherDevices;

  useEffect(() => {
    const ids = otherDevices.map((d) => d.deviceId);
    setDeviceReach((prev) => mergeReachOnListChange(prev, otherDevices, connected));

    const allowed = new Set(ids);
    const urls = { ...freshLanUrlsRef.current };
    for (const k of Object.keys(urls)) {
      if (!allowed.has(k)) delete urls[k];
    }
    freshLanUrlsRef.current = urls;
  }, [deviceFingerprint, connected, otherDevices]);

  useEffect(() => {
    const cancelledRef = { current: false };
    if (probeToken === 0 || !connected) {
      return () => { cancelledRef.current = true; };
    }

    const snap = deviceSnapshotRef.current;
    logger.info(TAG, 'probe run token=', probeToken, 'devices=', snap.length);

    setDeviceReach((prev) => {
      const next = { ...prev };
      for (const d of snap) next[d.deviceId] = toProbingEntry(prev[d.deviceId]);
      return next;
    });

    setProbing(true);
    let pending = snap.length;
    for (const d of snap) {
      void (async () => {
        try {
          const { methods, freshLanUrl } = await probeDeviceAllMethods(
            d, onDirectHttpProbe, onLanHttpProbe, onWebRTCProbe,
          );
          if (cancelledRef.current) return;
          if (freshLanUrl) {
            freshLanUrlsRef.current = { ...freshLanUrlsRef.current, [d.deviceId]: freshLanUrl };
          }
          setDeviceReach((prev) => ({
            ...prev,
            [d.deviceId]: toResolvedEntry(methods),
          }));
        } finally {
          pending--;
          if (pending <= 0 && !cancelledRef.current) setProbing(false);
        }
      })();
    }

    return () => { cancelledRef.current = true; };
  }, [probeToken, connected, onWebRTCProbe, onLanHttpProbe, onDirectHttpProbe]);

  const probeSingleDevice = useCallback((deviceId: string) => {
    if (!connected) return;
    const device = deviceSnapshotRef.current.find((d) => d.deviceId === deviceId);
    if (!device) return;

    setDeviceReach((prev) => ({
      ...prev,
      [deviceId]: toProbingEntry(prev[deviceId]),
    }));
    void (async () => {
      const { methods, freshLanUrl } = await probeDeviceAllMethods(
        device, onDirectHttpProbe, onLanHttpProbe, onWebRTCProbe,
      );
      if (freshLanUrl) {
        freshLanUrlsRef.current = { ...freshLanUrlsRef.current, [deviceId]: freshLanUrl };
      }
      setDeviceReach((prev) => ({
        ...prev,
        [deviceId]: toResolvedEntry(methods),
      }));
    })();
  }, [connected, onDirectHttpProbe, onLanHttpProbe, onWebRTCProbe]);

  return { deviceReach, freshLanUrlsRef, probing, probeSingleDevice };
}

export function sortDevicesByReach(
  devices: DeviceDto[],
  statusMap: Record<string, DeviceReachEntry>,
): DeviceDto[] {
  return [...devices].sort(
    (a, b) => reachSortPriority(statusMap[a.deviceId]) - reachSortPriority(statusMap[b.deviceId]),
  );
}
