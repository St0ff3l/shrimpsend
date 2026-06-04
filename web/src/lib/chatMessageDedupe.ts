import type { ChatMessage } from '@/lib/api';

export function normalizeMessageLocalId(v: unknown): string | undefined {
  if (v == null) return undefined;
  const s = String(v).trim();
  return s.length > 0 ? s : undefined;
}

/** 同一传输任务：顶层 _localId 或 payload.localId（避免类型/字段不一致导致无法合并） */
export function rowMatchesLocalId(m: ChatMessage, lid: string): boolean {
  const top = normalizeMessageLocalId(m._localId);
  if (top === lid) return true;
  const pl = m.payload;
  if (pl && typeof pl === 'object' && 'localId' in pl) {
    return normalizeMessageLocalId((pl as { localId?: unknown }).localId) === lid;
  }
  return false;
}
