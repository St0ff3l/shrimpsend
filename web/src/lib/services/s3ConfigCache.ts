const STORAGE_KEY = 's3_config_local';

export interface S3LocalConfig {
  endpoint: string;
  region: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
  /** Defaults to true (path-style) when omitted in cache. */
  pathStyleAccessEnabled?: boolean;
}

function normalizeEndpoint(endpoint: string): string {
  return endpoint.replace(/\/$/, '');
}

export const s3ConfigCache = {
  save(config: S3LocalConfig): void {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
    } catch {
      // localStorage may be unavailable in some contexts
    }
  },

  load(): S3LocalConfig | null {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return null;
      const parsed = JSON.parse(raw) as S3LocalConfig;
      parsed.endpoint = normalizeEndpoint(parsed.endpoint);
      return parsed;
    } catch {
      return null;
    }
  },

  clear(): void {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {
      // ignore
    }
  },
};
