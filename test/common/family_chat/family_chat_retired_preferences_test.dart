import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'migration removes retired speech settings without touching other metadata',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute(
        'CREATE TABLE chat_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      raw.execute('INSERT INTO chat_metadata VALUES (?, ?)', [
        'speech:old-scope',
        '{"enabled":true}',
      ]);
      raw.execute('INSERT INTO chat_metadata VALUES (?, ?)', [
        'shortcuts:old-scope',
        '{"revision":7}',
      ]);
      raw.execute('PRAGMA user_version=5');
      final db = FamilyChatDatabase(NativeDatabase.opened(raw));
      addTearDown(db.close);
      expect(await db.metadata('speech:old-scope'), isNull);
      expect(await db.metadata('shortcuts:old-scope'), {'revision': 7});
    },
  );
}
