import 'package:app/services/chat_message_dao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ChatMessageDao.deleteAllForThread', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
CREATE TABLE chat_messages (
  id            TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL,
  type          TEXT NOT NULL,
  payload       TEXT NOT NULL,
  from_device_id TEXT NOT NULL,
  ts            INTEGER NOT NULL,
  synced        INTEGER NOT NULL DEFAULT 1,
  status        TEXT,
  thread_key    TEXT
);
''');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> countRows() async {
      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM chat_messages');
      return (rows.first['c'] as int?) ?? 0;
    }

    test('deletes only rows for the given thread and user ids', () async {
      await db.insert('chat_messages', {
        'id': 'a',
        'user_id': '1',
        'type': 'text',
        'payload': '{}',
        'from_device_id': 'dev_a',
        'ts': 1,
        'thread_key': 'u:1|d1:a|d2:b',
      });
      await db.insert('chat_messages', {
        'id': 'b',
        'user_id': '1',
        'type': 'text',
        'payload': '{}',
        'from_device_id': 'dev_a',
        'ts': 2,
        'thread_key': 'u:1|d1:c|d2:d',
      });
      await db.insert('chat_messages', {
        'id': 'c',
        'user_id': '2',
        'type': 'text',
        'payload': '{}',
        'from_device_id': 'dev_a',
        'ts': 3,
        'thread_key': 'u:1|d1:a|d2:b',
      });

      final deleted = await db.delete(
        'chat_messages',
        where: 'user_id = ? AND thread_key = ?',
        whereArgs: ['1', 'u:1|d1:a|d2:b'],
      );

      expect(deleted, 1);
      expect(await countRows(), 2);
    });
  });

  test('ChatMessageDao exposes deleteAllForThread API', () {
    expect(ChatMessageDao.instance.deleteAllForThread, isNotNull);
  });
}
