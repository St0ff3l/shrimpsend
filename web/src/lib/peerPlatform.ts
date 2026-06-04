/** True when the peer device is a web browser client (web-to-web session). */
export function isWebPeer(platform?: string | null): boolean {
  return platform === 'web';
}
