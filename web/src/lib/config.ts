/**
 * 统一的服务地址推导。
 *
 * 规则：
 *   SSR（服务端渲染）→ 后端在同一台机器，统一用 localhost
 *   浏览器-本地网络 → 始终连接同 hostname 的本机服务端口
 *   非局域网（公网 Web）→ 始终 api.{当前 host} / ws.{当前 host}，不以本地国家码覆盖（区域由部署域名决定）
 */

const BACKEND_PORT = 9000;
const CENTRIFUGO_PORT = 8000;

function isLocalNetwork(): boolean {
  if (typeof window === 'undefined') return true;
  const h = window.location.hostname;
  return h === 'localhost' || h === '127.0.0.1' || h.startsWith('192.168.') || h.startsWith('10.');
}

export function getApiUrl(): string {
  if (typeof window === 'undefined') {
    return `http://localhost:${BACKEND_PORT}`;
  }
  if (isLocalNetwork()) {
    return `${window.location.protocol}//${window.location.hostname}:${BACKEND_PORT}`;
  }
  // 公网 Web：服务地址由当前部署域名决定，不再用本地存储的国家码覆盖。
  return `${window.location.protocol}//api.${window.location.host}`;
}

export function getCentrifugoWsUrl(): string {
  if (typeof window === 'undefined') {
    return `ws://localhost:${CENTRIFUGO_PORT}/connection/websocket`;
  }
  if (isLocalNetwork()) {
    return `ws://${window.location.hostname}:${CENTRIFUGO_PORT}/connection/websocket`;
  }
  const wsProto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  return `${wsProto}//ws.${window.location.host}/connection/websocket`;
}

/** 当前环境下解析出的 HTTP API 根 URL */
export function resolveBackendApiUrl(): string {
  return getApiUrl();
}
