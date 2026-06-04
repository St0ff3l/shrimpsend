import relationalStore from '@ohos.data.relationalStore';
import { common } from '@kit.AbilityKit';
import { MessageEnvelope } from '../network/MessagesApi';
import { ThreadKey } from '../chat/ThreadKey';
import { Log } from '../common/Logger';

const TAG = 'ChatRdb';
const DB_NAME = 'UltrasendChat.db';
const TABLE = 'chat_messages';

export interface LocalChatRow {
  id: string;
  userId: string;
  type: string;
  payloadJson: string;
  fromDeviceId: string;
  ts: number;
  synced: number;
  status: string;
  threadKey?: string;
}

export class ChatRdb {
  private static store: relationalStore.RdbStore | null = null;

  static async init(context: common.UIAbilityContext): Promise<void> {
    if (ChatRdb.store !== null) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    ChatRdb.store = await relationalStore.getRdbStore(context, config);
    await ChatRdb.ensureSchema();
  }

  static getDb(): relationalStore.RdbStore {
    if (ChatRdb.store === null) {
      throw new Error('ChatRdb not initialized');
    }
    return ChatRdb.store;
  }

  private static async ensureSchema(): Promise<void> {
    const sql =
      `CREATE TABLE IF NOT EXISTS ${TABLE} (` +
      `id TEXT PRIMARY KEY, ` +
      `user_id TEXT NOT NULL, ` +
      `type TEXT NOT NULL, ` +
      `payload TEXT NOT NULL, ` +
      `from_device_id TEXT NOT NULL, ` +
      `ts INTEGER NOT NULL, ` +
      `synced INTEGER NOT NULL DEFAULT 1, ` +
      `status TEXT` +
      `)`;
    await ChatRdb.getDb().executeSql(sql);
    await ChatRdb.getDb().executeSql(`CREATE INDEX IF NOT EXISTS idx_msg_ts ON ${TABLE}(ts)`);
    await ChatRdb.getDb().executeSql(`CREATE INDEX IF NOT EXISTS idx_msg_user_ts ON ${TABLE}(user_id, ts)`);
    try {
      await ChatRdb.getDb().executeSql(`ALTER TABLE ${TABLE} ADD COLUMN thread_key TEXT`);
      await ChatRdb.getDb().executeSql(
        `CREATE INDEX IF NOT EXISTS idx_msg_user_thread_ts ON ${TABLE}(user_id, thread_key, ts)`);
    } catch (_) {
      // column may already exist
    }
  }

  static rowIdForEnvelope(env: MessageEnvelope): string {
    if (env.id !== undefined && env.id > 0) {
      return `${env.id}`;
    }
    return `u_${env.ts}_${env.fromDeviceId}`;
  }

  static payloadToJson(payload: Object | string | number | boolean | null): string {
    if (typeof payload === 'string') {
      return payload;
    }
    return JSON.stringify(payload);
  }

  static async upsertMessage(userId: string, env: MessageEnvelope, status?: string): Promise<void> {
    const id = ChatRdb.rowIdForEnvelope(env);
    const payloadJson = ChatRdb.payloadToJson(env.payload);
    const account = ThreadKey.accountPartLoggedIn(userId);
    const threadKey =
      env.threadKey !== undefined && env.threadKey.length > 0 ? env.threadKey : ThreadKey.threadKeyLegacyBroadcast(account);
    const vb: relationalStore.ValuesBucket = {
      'id': id,
      'user_id': userId,
      'type': env.type,
      'payload': payloadJson,
      'from_device_id': env.fromDeviceId,
      'ts': env.ts,
      'synced': 1,
      'status': status ?? '',
      'thread_key': threadKey
    };
    const delPred = new relationalStore.RdbPredicates(TABLE);
    delPred.equalTo('id', id);
    await ChatRdb.getDb().delete(delPred);
    await ChatRdb.getDb().insert(TABLE, vb);
  }

  static async loadRecent(userId: string, limit: number = 50, threadKey?: string): Promise<LocalChatRow[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('user_id', userId);
    if (threadKey !== undefined && threadKey.length > 0) {
      predicates.equalTo('thread_key', threadKey);
    }
    predicates.orderByDesc('ts');
    predicates.limitAs(limit);
    const rs = await ChatRdb.getDb().query(predicates);
    const out: LocalChatRow[] = [];
    const tkIdx = rs.getColumnIndex('thread_key');
    while (await rs.goToNextRow()) {
      let tk: string | undefined = undefined;
      if (tkIdx >= 0) {
        tk = rs.getString(tkIdx);
      }
      const row: LocalChatRow = {
        id: rs.getString(rs.getColumnIndex('id')),
        userId: rs.getString(rs.getColumnIndex('user_id')),
        type: rs.getString(rs.getColumnIndex('type')),
        payloadJson: rs.getString(rs.getColumnIndex('payload')),
        fromDeviceId: rs.getString(rs.getColumnIndex('from_device_id')),
        ts: rs.getLong(rs.getColumnIndex('ts')),
        synced: rs.getLong(rs.getColumnIndex('synced')),
        status: rs.getString(rs.getColumnIndex('status')),
        threadKey: tk
      };
      out.push(row);
    }
    await rs.close();
    return out;
  }

  static async deleteById(id: string): Promise<void> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    await ChatRdb.getDb().delete(predicates);
  }
}
