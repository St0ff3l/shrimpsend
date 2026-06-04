import { MessagesApi, MessageEnvelope } from '../network/MessagesApi';
import { getOrCreateDeviceId } from '../storage/DeviceIdentity';

/** 信令仍走消息 API（与 Flutter sendWebRTCSignal 一致）；原生 RTC/DataChannel 见 WebRtcTransportPlaceholder */
export async function sendWebRtcSignal(signal: Record<string, Object>): Promise<void> {
  const deviceId = await getOrCreateDeviceId();
  const t = signal['type'];
  const typeStr = t !== undefined ? `${t}` : 'webrtc_unknown';
  const messageData: MessageEnvelope = {
    'type': typeStr,
    'payload': signal,
    'fromDeviceId': deviceId,
    'ts': Date.now()
  };
  await MessagesApi.sendMessage(messageData);
}
