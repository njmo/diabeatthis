import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/common/family_sync/family_mirror_status.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:diabeatthis/features/settings/data/database_backup_scope.dart';
import 'package:diabeatthis/features/settings/data/database_backup_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'import wakes sync only after commit, ignoring imported synced flags',
    () async {
      final source = DatabaseImpl(NativeDatabase.memory());
      final target = DatabaseImpl(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);
      await source.customStatement(
        "INSERT INTO portion(name,unit_hint,is_synced) VALUES('Imported','g',1)",
      );
      final backup = await DatabaseBackupService(
        source,
      ).exportToJson(DatabaseBackupScope.core);
      var requests = 0;
      final service = DatabaseBackupService(
        target,
        onImportCommitted: () async {
          expect(
            (await target.customSelect("SELECT name FROM portion").getSingle())
                .read<String>('name'),
            'Imported',
          );
          requests++;
          // Throwing wake-up must not invalidate a committed offline import.
          throw StateError('Background service unavailable');
        },
      );
      await service.importFromJson(backup);
      expect(requests, 1);
      expect(
        (await target
                .customSelect('SELECT requested FROM family_sync_runtime')
                .getSingle())
            .read<int>('requested'),
        1,
      );
      final pending = await FamilyMirrorOutbox(target).pending();
      expect(
        pending.any(
          (row) => row.kind == 'portions' && row.payload?['name'] == 'Imported',
        ),
        true,
      );
      final broken = {
        ...backup,
        'tables': {
          'portion': [
            {'invalid_column': 1},
          ],
        },
      };
      await expectLater(service.importFromJson(broken), throwsA(anything));
      expect(requests, 1);
      expect(
        (await FamilyMirrorOutbox(
          target,
        ).pending()).any((row) => row.payload?['name'] == 'Imported'),
        true,
      );
    },
  );

  test(
    'status distinguishes pending, active, failure and confirmed data',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime(2026, 11, 6);
      expect(await readFamilyMirrorStatus(db, now), FamilyMirrorStatus.hidden);
      await db.customStatement('UPDATE family_sync_identity SET enabled=1');
      await db.customStatement(
        "INSERT INTO portion(name,unit_hint) VALUES('Local','g')",
      );
      expect(await readFamilyMirrorStatus(db, now), FamilyMirrorStatus.waiting);
      await db.customStatement(
        'UPDATE family_sync_runtime SET active_until=?',
        [now.add(const Duration(minutes: 1)).millisecondsSinceEpoch],
      );
      expect(await readFamilyMirrorStatus(db, now), FamilyMirrorStatus.syncing);
      await db.customStatement('UPDATE family_sync_runtime SET active_until=0');
      await db.customStatement(
        "UPDATE family_sync_identity SET last_error='offline'",
      );
      expect(await readFamilyMirrorStatus(db, now), FamilyMirrorStatus.failed);
      await db.customStatement(
        'UPDATE family_sync_outbox SET failed_revision=revision',
      );
      expect(await readFamilyMirrorStatus(db, now), FamilyMirrorStatus.blocked);
      await db.customStatement(
        'UPDATE family_sync_outbox SET acknowledged_revision=revision',
      );
      await db.customStatement(
        'UPDATE family_sync_identity SET last_success=?',
        [now.millisecondsSinceEpoch],
      );
      expect(
        await readFamilyMirrorStatus(db, now),
        FamilyMirrorStatus.synchronized,
      );
      expect(
        await readFamilyMirrorStatus(db, now.add(const Duration(seconds: 6))),
        FamilyMirrorStatus.hidden,
      );
    },
  );
  test('multi-megabyte import queues bounded cloud batches', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final padding = List.filled(8192, 'a').join();
    final backup = {
      'formatVersion': 1,
      'scope': 'core',
      'tables': {
        'portion': List.generate(
          1200,
          (index) => {
            'id': index + 1,
            'name': '$index-$padding',
            'unit_hint': 'g',
            'is_synced': 1,
          },
        ),
      },
    };
    expect(
      utf8.encode(jsonEncode(backup)).length,
      greaterThan(9 * 1024 * 1024),
    );
    await DatabaseBackupService(db).importFromJson(backup);
    expect(
      (await db
              .customSelect('SELECT COUNT(*) AS count FROM portion')
              .getSingle())
          .read<int>('count'),
      1200,
    );
    expect(
      (await db
              .customSelect(
                'SELECT COUNT(*) AS count FROM family_sync_outbox WHERE revision>acknowledged_revision',
              )
              .getSingle())
          .read<int>('count'),
      1200,
    );
    expect(await FamilyMirrorOutbox(db).pending(), hasLength(25));
  });
  test(
    'a native wake-up without a reply cannot hold the import open',
    () async {
      const channel = MethodChannel('flutter_foreground_task/methods');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final reply = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (_) => reply.future);
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        if (!reply.isCompleted) reply.complete();
      });
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await DatabaseBackupService(db)
          .importFromJson({
            'formatVersion': 1,
            'scope': 'core',
            'tables': <String, Object?>{},
          })
          .timeout(const Duration(milliseconds: 500));
      expect(
        (await db
                .customSelect('SELECT requested FROM family_sync_runtime')
                .getSingle())
            .read<int>('requested'),
        1,
      );
    },
  );
}
