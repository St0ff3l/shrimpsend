import { sendMessage } from '@/lib/api';
import type { MessageEnvelope } from '@/lib/api';
import { getOrCreateDeviceId } from '@/lib/deviceId';
import { logger } from '@/lib/logger';

const TAG = 'SignalingChannel';

export type WebRTCSignalType =
  | 'webrtc_offer'
  | 'webrtc_answer'
  | 'webrtc_ice_candidate'
  | 'webrtc_transfer_cancel';

export interface WebRTCOffer {
  type: 'webrtc_offer';
  sessionId: string;
  senderDeviceId: string;
  targetDeviceId: string;
  sdp: string;
  files: Array<{
    fileId: string;
    fileName: string;
    fileSize: number;
    mimeType: string;
    /** Sender-assigned per-transfer local id (UUID); see `FileMetadata`. */
    senderLocalId?: string;
  }>;
}

export interface WebRTCAnswer {
  type: 'webrtc_answer';
  sessionId: string;
  senderDeviceId: string;
  targetDeviceId: string;
  sdp: string;
}

export interface WebRTCIceCandidate {
  type: 'webrtc_ice_candidate';
  sessionId: string;
  senderDeviceId: string;
  targetDeviceId: string;
  candidate: RTCIceCandidateInit;
}

export interface WebRTCTransferCancel {
  type: 'webrtc_transfer_cancel';
  sessionId: string;
  senderDeviceId: string;
  targetDeviceId: string;
}

export type WebRTCSignal = WebRTCOffer | WebRTCAnswer | WebRTCIceCandidate | WebRTCTransferCancel;

export function isWebRTCSignal(data: MessageEnvelope): data is MessageEnvelope & { payload: WebRTCSignal } {
  return (
    data.type === 'webrtc_offer' ||
    data.type === 'webrtc_answer' ||
    data.type === 'webrtc_ice_candidate' ||
    data.type === 'webrtc_transfer_cancel'
  );
}

export async function sendSignal(signal: WebRTCSignal): Promise<void> {
  logger.debug(TAG, `sendSignal type=${signal.type} session=${signal.sessionId}`);
  const envelope: MessageEnvelope = {
    type: signal.type as MessageEnvelope['type'],
    payload: signal,
    fromDeviceId: getOrCreateDeviceId(),
    ts: Date.now(),
  };
  await sendMessage(envelope);
}
