import { logger } from '../logger';
import type { CompletedPart, TransferRecord } from './transferRecord';
import { isResumable } from './transferRecord';

const STORAGE_KEY = 'transfer_records';
const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const TAG = 'transferState';

function loadAll(): TransferRecord[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as TransferRecord[];
  } catch {
    return [];
  }
}

function saveAll(records: TransferRecord[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(records));
}

export const transferStateManager = {
  saveRecord(record: TransferRecord): void {
    const records = loadAll();
    const idx = records.findIndex((r) => r.transferId === record.transferId);
    record.updatedAt = new Date().toISOString();
    if (idx >= 0) {
      records[idx] = record;
    } else {
      records.push(record);
    }
    saveAll(records);
  },

  updateProgress(
    transferId: string,
    transferredBytes: number,
    completedParts?: CompletedPart[],
  ): void {
    const records = loadAll();
    const r = records.find((x) => x.transferId === transferId);
    if (!r) return;
    r.transferredBytes = transferredBytes;
    r.updatedAt = new Date().toISOString();
    if (completedParts) r.s3CompletedParts = completedParts;
    saveAll(records);
  },

  markStatus(transferId: string, status: TransferRecord['status']): void {
    const records = loadAll();
    const idx = records.findIndex((r) => r.transferId === transferId);
    if (idx < 0) return;
    if (status === 'completed') {
      records.splice(idx, 1);
    } else {
      records[idx].status = status;
      records[idx].updatedAt = new Date().toISOString();
    }
    saveAll(records);
  },

  getRecord(transferId: string): TransferRecord | undefined {
    return loadAll().find((r) => r.transferId === transferId);
  },

  getResumableTransfers(): TransferRecord[] {
    return loadAll().filter(isResumable);
  },

  findResumable(opts: {
    channel: string;
    direction: string;
    s3Key?: string;
    fileName?: string;
    fileSize?: number;
  }): TransferRecord | undefined {
    const resumable = this.getResumableTransfers();
    for (const r of resumable) {
      if (r.channel !== opts.channel || r.direction !== opts.direction) continue;
      if (opts.s3Key && r.s3Key === opts.s3Key) return r;
      if (
        opts.fileName &&
        opts.fileSize !== undefined &&
        r.fileName === opts.fileName &&
        r.fileSize === opts.fileSize
      ) {
        return r;
      }
    }
    return undefined;
  },

  cleanExpired(): void {
    const records = loadAll();
    const now = Date.now();
    const kept = records.filter(
      (r) =>
        r.status === 'in_progress' ||
        now - new Date(r.updatedAt).getTime() < MAX_AGE_MS,
    );
    saveAll(kept);
    logger.info(TAG, 'cleanExpired remaining=', kept.length);
  },

  removeRecord(transferId: string): void {
    const records = loadAll().filter((r) => r.transferId !== transferId);
    saveAll(records);
  },

  clear(): void {
    saveAll([]);
  },
};
