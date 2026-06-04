import { OpenPanel } from '@openpanel/web';

import { getApiUrl } from '@/lib/config';
import { logger } from '@/lib/logger';

const TAG = 'OpenPanel';

let client: OpenPanel | null = null;
let warnedIntlMissingClientId = false;

function normalizeApiUrl(raw: string): string {
  let s = raw.trim();
  if (!s) return '';
  while (s.endsWith('/')) s = s.slice(0, -1);
  if (!s.endsWith('/api')) s = `${s}/api`;
  return s;
}

function isLanHost(hostname: string): boolean {
  return (
    hostname === 'localhost' ||
    hostname === '127.0.0.1' ||
    hostname.startsWith('192.168.') ||
    hostname.startsWith('10.')
  );
}

export type ResolvedOpenPanelWebConfig = {
  clientId: string;
  apiUrl: string;
  clientSecret?: string;
};

/**
 * 公网选用出海 ingest 的条件（任一满足即走 `NEXT_PUBLIC_OPENPANEL_INTL_*`）：
 * - `NEXT_PUBLIC_OPENPANEL_WEB_CLUSTER=intl`（自定义域名部署务必设置）
 * - `hostname` 含 `shrimpsend`
 * - 当前 `getApiUrl()` 指向 `*.shrimpsend.com`（与后端集群对齐）
 * 公网否则 → 国内 Web（`NEXT_PUBLIC_OPENPANEL_*`）。
 * 局域网：本地调试不初始化线上 OpenPanel，避免本地请求线上服务。
 */
function publicWebPrefersIntl(host: string): boolean {
  const cluster = process.env.NEXT_PUBLIC_OPENPANEL_WEB_CLUSTER?.trim().toLowerCase();
  if (cluster === 'intl') return true;
  if (cluster === 'cn') return false;

  const h = host.toLowerCase();
  if (h.includes('shrimpsend')) return true;

  try {
    const api = getApiUrl();
    if (api.toLowerCase().includes('shrimpsend.com')) return true;
  } catch {
    /* ignore */
  }

  return false;
}

export function resolveOpenPanelWebConfig():
  | ResolvedOpenPanelWebConfig
  | null {
  if (typeof window === 'undefined') return null;

  const host = window.location.hostname;

  const cnClientId = process.env.NEXT_PUBLIC_OPENPANEL_CLIENT_ID?.trim() ?? '';
  const cnApiUrl = normalizeApiUrl(
    process.env.NEXT_PUBLIC_OPENPANEL_API_URL ?? '',
  );
  const cnSecret = process.env.NEXT_PUBLIC_OPENPANEL_CLIENT_SECRET?.trim();

  const intlClientId =
    process.env.NEXT_PUBLIC_OPENPANEL_INTL_CLIENT_ID?.trim() ?? '';
  const intlApiUrl = normalizeApiUrl(
    process.env.NEXT_PUBLIC_OPENPANEL_INTL_API_URL ?? '',
  );
  const intlSecret =
    process.env.NEXT_PUBLIC_OPENPANEL_INTL_CLIENT_SECRET?.trim();

  const intlCfg = (): ResolvedOpenPanelWebConfig | null => {
    if (!intlClientId || !intlApiUrl) return null;
    return {
      clientId: intlClientId,
      apiUrl: intlApiUrl,
      clientSecret: intlSecret || undefined,
    };
  };

  const cnCfg = (): ResolvedOpenPanelWebConfig | null => {
    if (!cnClientId || !cnApiUrl) return null;
    return {
      clientId: cnClientId,
      apiUrl: cnApiUrl,
      clientSecret: cnSecret || undefined,
    };
  };

  if (!isLanHost(host)) {
    if (publicWebPrefersIntl(host)) {
      const intl = intlCfg();
      if (!intl && !warnedIntlMissingClientId) {
        warnedIntlMissingClientId = true;
        logger.warn(
          TAG,
          '公网已判定为出海集群，但未配置 NEXT_PUBLIC_OPENPANEL_INTL_CLIENT_ID（或为空），OpenPanel 不会初始化；'
            + '请在部署环境写入 INTL 的 client id / secret，或设置 NEXT_PUBLIC_OPENPANEL_WEB_CLUSTER=cn 强制走国内 ingest。',
        );
      }
      return intl;
    }
    return cnCfg();
  }

  return null;
}

export function getOpenPanelClient(): OpenPanel | null {
  return client;
}

/** 幂等；仅在浏览器调用。 */
export function initOpenPanelInBrowser(): void {
  if (typeof window === 'undefined') return;
  if (client) return;

  const cfg = resolveOpenPanelWebConfig();
  if (!cfg) return;

  client = new OpenPanel({
    clientId: cfg.clientId,
    apiUrl: cfg.apiUrl,
    clientSecret: cfg.clientSecret,
    trackScreenViews: false,
    trackOutgoingLinks: true,
    trackAttributes: true,
  });

  if (process.env.NODE_ENV === 'development') {
    logger.info(TAG, 'enabled', cfg.apiUrl);
  }
}
