import { logger } from '../logger';
import { getApiUrl, AuthError, getToken, withAuthRetry } from './client';

/** multipart POST with XMLHttpRequest so upload progress is available */
function xhrMultipartPost(
  url: string,
  form: FormData,
  token: string,
  onUploadProgress?: (loaded: number, total: number) => void,
): Promise<{ status: number; bodyText: string }> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', url);
    xhr.setRequestHeader('Authorization', `Bearer ${token}`);
    xhr.upload.onprogress = (ev) => {
      if (ev.lengthComputable && ev.total > 0 && onUploadProgress) {
        onUploadProgress(ev.loaded, ev.total);
      }
    };
    xhr.onload = () => resolve({ status: xhr.status, bodyText: xhr.responseText ?? '' });
    xhr.onerror = () => reject(new Error('网络错误，上传中断'));
    xhr.send(form);
  });
}

/**
 * 直传到对象存储：浏览器对预签名 URL 发 PUT。
 *
 * 仅设置 Content-Type（必须与签名 contentType 严格一致），不要设置 Authorization 或其它自定义头，
 * 以避免触发 CORS preflight 失败或签名不一致。
 */
function xhrPutToPresignedUrl(
  url: string,
  file: File,
  contentType: string,
  onUploadProgress?: (loaded: number, total: number) => void,
): Promise<{ status: number; bodyText: string }> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('PUT', url);
    xhr.setRequestHeader('Content-Type', contentType);
    xhr.upload.onprogress = (ev) => {
      if (ev.lengthComputable && ev.total > 0 && onUploadProgress) {
        onUploadProgress(ev.loaded, ev.total);
      }
    };
    xhr.onload = () => resolve({ status: xhr.status, bodyText: xhr.responseText ?? '' });
    xhr.onerror = () => reject(new Error('网络错误，上传中断（CORS 或网络）'));
    xhr.ontimeout = () => reject(new Error('上传超时'));
    xhr.send(file);
  });
}

const TAG = 'adminAppVersion';

export type ReleasePresignResponse = {
  uploadUrl: string;
  key: string;
  publicUrl: string;
};

/** 上传完成后的统一返回结构（直传 / 后端中转通用） */
export type ReleaseServerUploadResponse = {
  key: string;
  publicUrl: string;
  sizeBytes: number;
};

export type AdminAppVersionRow = {
  id: number;
  version: string;
  buildNumber: number;
  downloadUrl: string;
  releaseNotes: string;
  iosStoreUrl: string;
  desktopWindowsZipUrl: string;
  desktopMacosZipUrl: string;
  desktopLinuxZipUrl: string;
  desktopWindowsZipBytes: number | null;
  desktopMacosZipBytes: number | null;
  desktopLinuxZipBytes: number | null;
  enabled: boolean;
  webPublished: boolean;
  publicMacUrlMainland: string;
  publicWinUrlMainland: string;
  publicApkUrlMainland: string;
  publicIosStoreUrlMainland: string;
  publicMacUrlOverseas: string;
  publicWinUrlOverseas: string;
  publicGooglePlayUrlOverseas: string;
  publicAppStoreUrlOverseas: string;
  publicApkUrlOverseas: string;
  mainlandPublicConfigured: boolean;
  overseasPublicConfigured: boolean;
  overseasPlayConfigured: boolean;
  overseasAppStoreConfigured: boolean;
  releasedAt?: string;
};

export type CreateAppVersionBody = {
  version: string;
  buildNumber: number;
  downloadUrl?: string;
  releaseNotes?: string;
  iosStoreUrl?: string;
  desktopWindowsZipUrl?: string;
  desktopMacosZipUrl?: string;
  desktopLinuxZipUrl?: string;
  desktopWindowsZipBytes?: number | null;
  desktopMacosZipBytes?: number | null;
  desktopLinuxZipBytes?: number | null;
  enabled?: boolean;
  webPublished?: boolean;
  publicMacUrlMainland?: string;
  publicWinUrlMainland?: string;
  publicApkUrlMainland?: string;
  publicIosStoreUrlMainland?: string;
  publicMacUrlOverseas?: string;
  publicWinUrlOverseas?: string;
  publicGooglePlayUrlOverseas?: string;
  publicAppStoreUrlOverseas?: string;
  publicApkUrlOverseas?: string;
};

export type UpdateAppVersionBody = Partial<{
  version: string;
  buildNumber: number;
  downloadUrl: string | null;
  releaseNotes: string | null;
  iosStoreUrl: string | null;
  desktopWindowsZipUrl: string | null;
  desktopMacosZipUrl: string | null;
  desktopLinuxZipUrl: string | null;
  desktopWindowsZipBytes: number | null;
  desktopMacosZipBytes: number | null;
  desktopLinuxZipBytes: number | null;
  enabled: boolean;
  webPublished: boolean;
  publicMacUrlMainland: string | null;
  publicWinUrlMainland: string | null;
  publicApkUrlMainland: string | null;
  publicIosStoreUrlMainland: string | null;
  publicMacUrlOverseas: string | null;
  publicWinUrlOverseas: string | null;
  publicGooglePlayUrlOverseas: string | null;
  publicAppStoreUrlOverseas: string | null;
  publicApkUrlOverseas: string | null;
}>;

export async function publishWebAdminAppVersion(id: number): Promise<AdminAppVersionRow> {
  logger.info(TAG, 'publishWebAdminAppVersion id=', id);
  return adminJson<AdminAppVersionRow>(`/api/admin/app-versions/${id}/publish-web`, {
    method: 'PATCH',
  });
}

async function adminJson<T>(path: string, init?: RequestInit): Promise<T> {
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('未登录');
    const res = await fetch(`${getApiUrl()}${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        ...init?.headers,
      },
    });
    if (res.status === 403) {
      const err = await res.json().catch(() => ({}));
      throw new Error((err as { error?: string }).error ?? '无权访问后台');
    }
    if (res.status === 401) throw new AuthError();
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error((err as { error?: string }).error ?? `请求失败 (${res.status})`);
    }
    if (res.status === 204 || res.headers.get('content-length') === '0') {
      return undefined as T;
    }
    const text = await res.text();
    if (!text) return undefined as T;
    return JSON.parse(text) as T;
  });
}

export async function listAdminAppVersions(): Promise<AdminAppVersionRow[]> {
  logger.info(TAG, 'listAdminAppVersions');
  const data = await adminJson<AdminAppVersionRow[]>('/api/admin/app-versions', { method: 'GET' });
  logger.info(TAG, 'listAdminAppVersions count=', data?.length ?? 0);
  return data;
}

export async function createAdminAppVersion(body: CreateAppVersionBody): Promise<AdminAppVersionRow> {
  logger.info(TAG, 'createAdminAppVersion build=', body.buildNumber);
  return adminJson<AdminAppVersionRow>('/api/admin/app-versions', {
    method: 'POST',
    body: JSON.stringify(body),
  });
}

export async function updateAdminAppVersion(
  id: number,
  body: UpdateAppVersionBody,
): Promise<AdminAppVersionRow> {
  logger.info(TAG, 'updateAdminAppVersion id=', id);
  return adminJson<AdminAppVersionRow>(`/api/admin/app-versions/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(body),
  });
}

export async function deleteAdminAppVersion(id: number): Promise<void> {
  logger.info(TAG, 'deleteAdminAppVersion id=', id);
  await adminJson<void>(`/api/admin/app-versions/${id}`, { method: 'DELETE' });
}

export type ReleaseUploadProgress = {
  loaded: number;
  total: number;
  /** 0–100，仅在 total 已知时有效 */
  percent: number;
};

export async function presignReleaseUpload(params: {
  platform: 'apk' | 'windows' | 'macos' | 'linux';
  buildNumber: number;
  fileName: string;
  contentType?: string;
}): Promise<ReleasePresignResponse> {
  logger.info(TAG, 'presignReleaseUpload platform=', params.platform);
  return adminJson<ReleasePresignResponse>('/api/admin/release/presign', {
    method: 'POST',
    body: JSON.stringify({
      platform: params.platform,
      buildNumber: params.buildNumber,
      fileName: params.fileName,
      contentType: params.contentType ?? 'application/octet-stream',
    }),
  });
}

/**
 * 浏览器直传发行包：先调后端预签名，再用 XHR PUT 直传到 COS / R2。
 *
 * 与经服务端中转的 {@link uploadReleaseViaServer} 相比，此实现不占用应用服务器带宽与内存，
 * 但要求目标对象存储桶（腾讯云 COS / Cloudflare R2）已配置允许后台域名的 CORS 规则
 * （AllowedMethod 至少包含 PUT, AllowedHeader 至少 Content-Type, ExposeHeader 包含 ETag）。
 */
export async function uploadReleaseDirect(
  params: {
    platform: 'apk' | 'windows' | 'macos' | 'linux';
    buildNumber: number;
    file: File;
    /** 规范化后的对象名，须与后端 sanitize 规则一致 */
    fileName: string;
  },
  onUploadProgress?: (p: ReleaseUploadProgress) => void,
): Promise<ReleaseServerUploadResponse> {
  logger.info(TAG, 'uploadReleaseDirect platform=', params.platform, 'size=', params.file.size);
  const contentType = params.file.type && params.file.type.length > 0
    ? params.file.type
    : 'application/octet-stream';

  const presigned = await presignReleaseUpload({
    platform: params.platform,
    buildNumber: params.buildNumber,
    fileName: params.fileName,
    contentType,
  });

  const res = await xhrPutToPresignedUrl(
    presigned.uploadUrl,
    params.file,
    contentType,
    (loaded, total) => {
      if (onUploadProgress && total > 0) {
        const percent = Math.min(100, Math.round((loaded / total) * 100));
        onUploadProgress({ loaded, total, percent });
      }
    },
  );

  if (res.status < 200 || res.status >= 300) {
    let msg = `直传失败 (${res.status})`;
    const snippet = (res.bodyText || '').trim();
    if (snippet) {
      msg += `: ${snippet.slice(0, 200)}`;
    }
    throw new Error(msg);
  }

  return {
    key: presigned.key,
    publicUrl: presigned.publicUrl,
    sizeBytes: params.file.size,
  };
}

/**
 * 兜底通道：先上传到同源后端，再由服务端写入 COS / R2。
 *
 * 已被 {@link uploadReleaseDirect}（浏览器直传预签名 URL）取代，但保留作为应急回退
 * （例如目标桶尚未配置 CORS、或网络环境阻止跨源 PUT 时使用）。
 * 使用 XHR 以支持 {@link onUploadProgress}。
 */
export async function uploadReleaseViaServer(
  params: {
    platform: 'apk' | 'windows' | 'macos' | 'linux';
    buildNumber: number;
    file: File;
    /** 规范化后的对象名，须与后端 sanitize 规则一致 */
    fileName: string;
  },
  onUploadProgress?: (p: ReleaseUploadProgress) => void,
): Promise<ReleaseServerUploadResponse> {
  logger.info(TAG, 'uploadReleaseViaServer platform=', params.platform, 'size=', params.file.size);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('未登录');
    const form = new FormData();
    form.append('file', params.file);
    form.append('platform', params.platform);
    form.append('buildNumber', String(params.buildNumber));
    form.append('fileName', params.fileName);

    const url = `${getApiUrl()}/api/admin/release/upload`;
    const res = await xhrMultipartPost(url, form, token, (loaded, total) => {
      if (onUploadProgress && total > 0) {
        const percent = Math.min(100, Math.round((loaded / total) * 100));
        onUploadProgress({ loaded, total, percent });
      }
    });

    if (res.status === 403) {
      let msg = '无权访问后台';
      try {
        const j = JSON.parse(res.bodyText) as { error?: string };
        if (j.error) msg = j.error;
      } catch {
        /* ignore */
      }
      throw new Error(msg);
    }
    if (res.status === 401) throw new AuthError();
    if (res.status < 200 || res.status >= 300) {
      let msg = `上传失败 (${res.status})`;
      try {
        const j = JSON.parse(res.bodyText) as { error?: string };
        if (j.error) msg = j.error;
      } catch {
        /* ignore */
      }
      throw new Error(msg);
    }
    try {
      return JSON.parse(res.bodyText || '{}') as ReleaseServerUploadResponse;
    } catch {
      throw new Error('服务器返回无效数据');
    }
  });
}
