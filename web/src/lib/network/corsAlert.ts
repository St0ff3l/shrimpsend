/**
 * 跨域/网络失败的统一上报与监听总线。
 *
 * 浏览器无法严格区分「CORS 阻断」「DNS/离线/连接重置」等错误，
 * 这里统一归为「疑似 CORS/网络失败」，由全局 Dialog 给出一个温和的提示，
 * 帮助用户检查目标存储桶 / 局域网设备的 CORS 配置。
 */

export type CorsAlertMode = 'upload' | 'download';
export type CorsAlertChannel = 's3' | 'lan' | 'webrtc-signal' | 'other';

export type CorsAlertPayload = {
  url?: string;
  mode: CorsAlertMode;
  channel: CorsAlertChannel;
  cause?: unknown;
};

type Listener = (payload: CorsAlertPayload) => void;

let currentListener: Listener | null = null;
const recentReports = new Map<string, number>();
const DEDUPE_WINDOW_MS = 5_000;

export function setCorsAlertListener(fn: Listener | null): void {
  currentListener = fn;
}

/** 仅当当前页面已在浏览器环境运行时才会真正触发监听器。 */
export function reportCorsLikely(payload: CorsAlertPayload): void {
  if (typeof window === 'undefined') return;
  if (!currentListener) return;
  if (payload.url && !isCrossOrigin(payload.url)) return;

  const key = `${payload.mode}:${payload.url ?? ''}`;
  const now = Date.now();
  const last = recentReports.get(key) ?? 0;
  if (now - last < DEDUPE_WINDOW_MS) return;
  recentReports.set(key, now);

  try {
    currentListener(payload);
  } catch {
    // listener 抛错不影响业务流。
  }
}

/** 用于业务函数透传结构化信息（可选）。 */
export class CorsLikelyError extends Error {
  readonly url?: string;
  readonly mode: CorsAlertMode;
  readonly channel: CorsAlertChannel;
  override readonly cause?: unknown;

  constructor(payload: CorsAlertPayload, message?: string) {
    super(message ?? 'errors.networkOrCors');
    this.name = 'CorsLikelyError';
    this.url = payload.url;
    this.mode = payload.mode;
    this.channel = payload.channel;
    this.cause = payload.cause;
  }
}

/**
 * 判断 `fetch` 抛出的异常是否「疑似网络/CORS」。
 *
 * - `AbortError` 视为主动取消，返回 false。
 * - `TypeError` 是 fetch 在 CORS 阻断 / DNS 失败 / 网络中断时统一抛出的类型。
 * - 兼容 Chrome (`Failed to fetch`) / Firefox (`NetworkError when attempting to fetch resource`) /
 *   Safari/WebKit (`Load failed`、`The network connection was lost`)。
 */
export function isLikelyNetworkOrCorsError(err: unknown): boolean {
  if (err == null) return false;
  if (err instanceof DOMException && err.name === 'AbortError') return false;
  if (err instanceof CorsLikelyError) return true;
  if (!(err instanceof Error)) return false;
  if (err.name === 'AbortError') return false;
  if (err.name !== 'TypeError') return false;
  const msg = err.message ?? '';
  return (
    /failed to fetch/i.test(msg) ||
    /networkerror/i.test(msg) ||
    /network request failed/i.test(msg) ||
    /load failed/i.test(msg) ||
    /network connection was lost/i.test(msg)
  );
}

/**
 * 在 XHR 的 `onerror` / `ontimeout` / `onload`(status===0) 分支里使用：
 * 排除手动 abort 后，剩下的 status===0 几乎都来自 CORS 阻断或链路异常。
 */
export function inspectXhrLikelyCors(
  xhr: XMLHttpRequest,
  options?: { aborted?: boolean; abortSignal?: AbortSignal },
): boolean {
  if (options?.aborted) return false;
  if (options?.abortSignal?.aborted) return false;
  return xhr.status === 0;
}

/** 仅当 URL 与当前页面同源时返回 false；解析失败时保守返回 true。 */
export function isCrossOrigin(url: string): boolean {
  if (typeof window === 'undefined') return false;
  try {
    const target = new URL(url, window.location.href);
    return target.origin !== window.location.origin;
  } catch {
    return true;
  }
}
