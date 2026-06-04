/** Shared helpers for Centrifugo `file` message payloads. */

export type FilePayloadLike = {
  key?: string;
  fileName?: string;
  webrtc?: boolean;
  lan?: boolean;
  targetDeviceIds?: string[];
  targetDeviceId?: string;
};

export function filePayloadTransferChannel(fp: FilePayloadLike): string | undefined {
  if (fp.webrtc) return 'webrtc';
  if (fp.lan) return 'lan';
  if (fp.targetDeviceIds != null && fp.targetDeviceIds.length > 0) return 'lan';
  if (fp.key) return 's3';
  return undefined;
}
