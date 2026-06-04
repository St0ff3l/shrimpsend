import { Log } from '../../common/Logger';

const TAG = 'MsgPreview';

/** 与计划一致：用于气泡样式分支 */
export type MessageCategory = 'user_text' | 'file' | 'system_link' | 'webrtc' | 'other';

export interface MessagePreview {
  title: string;
  subtitle: string;
  category: MessageCategory;
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** 会话列表侧时间展示 */
export function formatChatTime(tsMillis: number): string {
  const d = new Date(tsMillis);
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

function formatFileSize(bytes: number): string {
  if (!isFinite(bytes) || bytes <= 0) {
    return '';
  }
  if (bytes < 1024) {
    return `${Math.round(bytes)} B`;
  }
  if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(1)} KB`;
  }
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function readNum(o: Record<string, Object>, key: string): number | undefined {
  const v = o[key];
  if (typeof v === 'number') {
    return v;
  }
  if (typeof v === 'string') {
    const n = parseInt(v, 10);
    if (!isNaN(n)) {
      return n;
    }
  }
  return undefined;
}

function readStr(o: Record<string, Object>, key: string): string {
  const v = o[key];
  if (v === undefined || v === null) {
    return '';
  }
  return `${v}`;
}

/** 从 payload 抽取一行补充说明 */
function buildPayloadSubtitle(p: Record<string, Object>): string {
  const parts: string[] = [];
  const keys = ['message', 'reason', 'error', 'detail', 'path', 'url', 'peerDeviceId', 'deviceId', 'mode'];
  for (let i = 0; i < keys.length; i++) {
    const s = readStr(p, keys[i]);
    if (s.length > 0) {
      parts.push(s);
    }
  }
  return parts.join(' · ');
}

/** 已知 type 的中文标题（链路/探测/WebRTC 信令等） */
function titleForSignalType(type: string): string {
  const table: Record<string, string> = {
    'link_credentials': '链路凭证',
    'link_established': '链路已建立',
    'link_failed': '链路失败',
    'link_joined': '已加入链路',
    'p2p_failed': '点对点失败',
    'lan_pull_probe': '局域网拉取探测',
    'lan_pull_probe_result': '拉取探测结果',
    'lan_http_probe': 'HTTP 探测',
    'lan_http_probe_result': 'HTTP 探测结果',
    'webrtc_probe': 'WebRTC 探测',
    'webrtc_probe_result': 'WebRTC 探测结果',
    'lan_file_offer': '局域网文件提议',
    'webrtc_offer': 'WebRTC 提议',
    'webrtc_answer': 'WebRTC 应答',
    'webrtc_ice_candidate': 'ICE 候选',
    'webrtc_transfer_cancel': '传输取消'
  };
  const hit = table[type];
  if (hit !== undefined && hit.length > 0) {
    return hit;
  }
  if (type.startsWith('link_')) {
    return `链路 · ${type.substring('link_'.length)}`;
  }
  if (type.startsWith('lan_')) {
    return `局域网 · ${type.substring('lan_'.length)}`;
  }
  if (type.startsWith('p2p_')) {
    return `P2P · ${type.substring('p2p_'.length)}`;
  }
  if (type.startsWith('webrtc_')) {
    return `WebRTC · ${type.substring('webrtc_'.length)}`;
  }
  return type.replace(/_/g, ' ');
}

function inferCategory(type: string): MessageCategory {
  if (type === 'text') {
    return 'user_text';
  }
  if (type === 'file') {
    return 'file';
  }
  if (type.startsWith('webrtc_')) {
    return 'webrtc';
  }
  if (type.startsWith('link_') || type.startsWith('lan_') || type.startsWith('p2p_')) {
    return 'system_link';
  }
  if (type.indexOf('probe') >= 0) {
    return 'system_link';
  }
  return 'other';
}

function trimSnippet(s: string, maxLen: number): string {
  if (s.length <= maxLen) {
    return s;
  }
  return `${s.substring(0, maxLen)}…`;
}

export class MessagePreviewFormatter {
  static format(type: string, payloadJson: string): MessagePreview {
    let p: Record<string, Object> = {};
    try {
      if (payloadJson.length > 0) {
        const parsed: Record<string, Object> | null = JSON.parse(payloadJson);
        if (typeof parsed === 'object' && parsed !== null) {
          p = parsed as Record<string, Object>;
        }
      }
    } catch (e) {
      Log.warn(TAG, 'payload parse %{public}s', JSON.stringify(e));
    }

    if (type === 'text') {
      const body = readStr(p, 'text');
      return {
        title: body.length > 0 ? body : '（空文本）',
        subtitle: '',
        category: 'user_text'
      };
    }

    if (type === 'file') {
      const name = readStr(p, 'fileName');
      const size = readNum(p, 'fileSize');
      const sz = size !== undefined ? formatFileSize(size) : '';
      const title = name.length > 0 ? name : '文件';
      const subParts: string[] = [];
      if (sz.length > 0) {
        subParts.push(sz);
      }
      const st = readStr(p, 'status');
      if (st.length > 0) {
        subParts.push(st);
      }
      return {
        title: `📎 ${title}`,
        subtitle: subParts.join(' · '),
        category: 'file'
      };
    }

    const cat = inferCategory(type);
    const title = titleForSignalType(type);
    const sub = buildPayloadSubtitle(p);
    if (cat === 'webrtc' || cat === 'system_link') {
      return {
        title,
        subtitle: sub,
        category: cat
      };
    }

    const fallbackTitle = readStr(p, 'text');
    if (fallbackTitle.length > 0) {
      return {
        title: trimSnippet(fallbackTitle, 200),
        subtitle: sub,
        category: 'other'
      };
    }
    const msg = readStr(p, 'message');
    if (msg.length > 0) {
      return {
        title: `${titleForSignalType(type)}：${trimSnippet(msg, 120)}`,
        subtitle: sub,
        category: 'other'
      };
    }
    const fn = readStr(p, 'fileName');
    if (fn.length > 0) {
      const szn = readNum(p, 'fileSize');
      return {
        title: fn,
        subtitle: szn !== undefined ? formatFileSize(szn) : sub,
        category: 'other'
      };
    }

    try {
      const raw = payloadJson.length > 120 ? `${payloadJson.substring(0, 120)}…` : payloadJson;
      return {
        title: `${titleForSignalType(type)}`,
        subtitle: raw.length > 0 ? trimSnippet(raw, 80) : sub,
        category: cat === 'other' ? 'other' : cat
      };
    } catch (_) {
      return {
        title: titleForSignalType(type),
        subtitle: '',
        category: 'other'
      };
    }
  }
}
