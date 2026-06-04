/**
 * 原生 DataChannel / RTCPeerConnection 需在后续迭代接入 HarmonyOS WebRTC 能力。
 * 信令已通过 {@link sendWebRtcSignal} 走消息 API + Centrifugo，与 protocol.md 一致。
 */
export class WebRtcTransportPlaceholder {
  static readonly note = 'WebRTC P2P 传输占位：待接 ArkWeb / 原生 RTC Kit';
}
