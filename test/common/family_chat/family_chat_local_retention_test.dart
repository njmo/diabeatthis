import 'dart:io';

import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  const day = 86400000;
  for (final promotion in [true, false]) {
    test(
      'retry preserves the original body deadline: promotion=$promotion',
      () async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.applyRetention('a', {'revision': 1, 'retention': 'day'});
        await db.enqueueUnsentReply(
          'a',
          'old',
          'peer',
          {'text': 'same body'},
          100,
          'marker',
        );
        await db.applyRetention('a', {'revision': 2, 'retention': 'unlimited'});
        await db.addTickets('a', [
          {'id': 'signed', 'token': 'signed', 'expiresAt': 9000},
        ]);
        if (promotion) {
          expect(await db.promoteNotificationDraft('a', 'old', 200), 'signed');
        } else {
          final row = (await db.outbox('a')).single;
          await db.complete('a', 'old');
          await db.enqueue(
            'a',
            'peer',
            {'text': 'same body'},
            200,
            originalLifetime: (
              at: row.read<int>('created_at'),
              policyRevision: row.read<int>('policy_revision'),
              until: row.readNullable<int>('retention_until'),
            ),
          );
        }
        final row = (await db.outbox('a')).single;
        expect(row.read<int>('created_at'), 100);
        expect(row.read<int>('retention_until'), day + 100);
        await db.purge('a', day + 100);
        expect(await db.outbox('a'), isEmpty);
        expect(await db.outcomeMarkers('a'), hasLength(1));
      },
    );
  }
  test(
    'schema4 migration and two connections preserve the purge highwater',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chat-retention-',
      );
      final file = File('${directory.path}/chat.sqlite');
      var db = FamilyChatDatabase(NativeDatabase(file));
      await db.saveDraft('a', 'peer', 'legacy', serverNow: 100);
      await db.close();
      final raw = sqlite3.open(file.path);
      for (final column in [
        'updated_at',
        'retention_until',
        'policy_revision',
      ]) {
        raw.execute('ALTER TABLE chat_drafts DROP COLUMN $column');
      }
      for (final column in ['retention_until', 'policy_revision']) {
        raw.execute('ALTER TABLE chat_outbox DROP COLUMN $column');
      }
      raw.execute('PRAGMA user_version=4');
      raw.dispose();
      db = FamilyChatDatabase(NativeDatabase(file));
      final other = FamilyChatDatabase(NativeDatabase(file));
      try {
        expect(await db.draft('a', 'peer'), 'legacy');
        await db.applyRetention('a', {
          'revision': 2,
          'retention': 'unlimited',
          'shortenings': [
            {'revision': 2, 'days': 1},
          ],
        });
        await db.purge('a', 2 * day);
        expect(await db.draft('a', 'peer'), '');
        expect(
          await other.saveMessage('a', 'peer', {
            'id': 'late',
            'sentAt': 100,
            'sequence': 1,
            'policyRevision': 1,
          }, serverNow: 100),
          isFalse,
        );
        expect(await other.messages('a', 'peer'), isEmpty);
        await other.saveDraft(
          'a',
          'peer',
          'stale',
          serverNow: 100,
          edit: (at: 100, policyRevision: 1, until: day + 100),
        );
        expect(await other.draft('a', 'peer'), '');
        expect(
          await other.enqueueUnsentReply(
            'a',
            'old',
            'peer',
            {'text': 'expired reply'},
            100,
            'marker',
            policy: {'revision': 1, 'retention': 'day'},
          ),
          isFalse,
        );
        await other.addTickets('a', [
          {'id': 'old-ticket', 'token': 'signed', 'expiresAt': 9000},
        ]);
        expect(
          await other.enqueue(
            'a',
            'peer',
            {'text': 'expired send'},
            100,
            policy: {'revision': 1, 'retention': 'day'},
          ),
          isNull,
        );
        expect(await other.outbox('a'), isEmpty);
      } finally {
        await other.close();
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test('enqueue checks the current clock after a delayed writer', () async {
    final db = FamilyChatDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addTickets('a', [
      {'id': 'op', 'token': 'signed', 'expiresAt': 1000},
    ]);
    await db.enqueue(
      'a',
      'peer',
      {'text': 'old'},
      200,
      composerDraft: 'old',
      latestDraft: () => 'new',
      latestDraftEdit: () => (at: 100, policyRevision: 1, until: day + 100),
      currentServerNow: () => 2 * day,
    );
    expect(await db.draft('a', 'peer'), '');
  });
  test(
    'enqueue preserves the actual newer draft edit deadline after policy extension',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.applyRetention('a', {
        'revision': 3,
        'retention': 'unlimited',
        'shortenings': [
          {'revision': 2, 'days': 1},
        ],
      });
      await db.addTickets('a', [
        {'id': 'op', 'token': 'signed', 'expiresAt': 1000},
      ]);
      await db.enqueue(
        'a',
        'peer',
        {'text': 'old'},
        200,
        composerDraft: 'old',
        latestDraft: () => 'new',
        latestDraftEdit: () => (at: 100, policyRevision: 2, until: day + 100),
      );
      expect(await db.draft('a', 'peer'), 'new');
      await db.purge('a', day + 100);
      expect(await db.draft('a', 'peer'), '');
    },
  );
  for (final period in {
    'day': 1,
    'week': 7,
    'month': 30,
    'unlimited': null,
  }.entries) {
    test('draft lifetime ${period.key} is frozen across autosave', () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.applyRetention('a', {'revision': 1, 'retention': period.key});
      await db.saveDraft('a', 'peer', 'hello', serverNow: 100);
      await db.saveDraft('a', 'peer', 'hello', serverNow: day);
      final end = period.value == null ? 1000 * day : 100 + period.value! * day;
      await db.purge('a', end - 1);
      expect(await db.draft('a', 'peer'), 'hello');
      await db.purge('a', end);
      expect(await db.draft('a', 'peer'), period.value == null ? 'hello' : '');
      if (period.value != null) {
        await db.saveDraft(
          'a',
          'peer',
          'hello',
          serverNow: end + 1,
          allowCreate: false,
        );
        expect(await db.draft('a', 'peer'), '');
      }
    });
  }

  test(
    'shortening survives extension, late draft flush and late message response',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.applyRetention('a', {'revision': 1, 'retention': 'unlimited'});
      await db.saveDraft('a', 'peer', 'private', serverNow: 100);
      await db.saveDraft('b', 'peer', 'other family', serverNow: 100);
      final policy = {
        'revision': 3,
        'retention': 'unlimited',
        'shortenings': [
          {'revision': 2, 'days': 1},
        ],
      };
      await db.applyRetention('a', policy);
      await db.saveDraft(
        'a',
        'late',
        'old edit',
        serverNow: day + 101,
        edit: (at: 100, policyRevision: 1, until: null),
      );
      expect(await db.draft('a', 'late'), '');
      await db.saveMessage('a', 'peer', {
        'id': 'late',
        'sentAt': 100,
        'sequence': 1,
        'policyRevision': 1,
        'expiresAt': null,
      });
      expect((await db.messages('a', 'peer')).single['expiresAt'], day + 100);
      await db.purge('a', day + 100);
      expect(
        await db.saveMessage('a', 'peer', {
          'id': 'late',
          'sentAt': 100,
          'sequence': 1,
          'policyRevision': 1,
          'expiresAt': null,
        }, serverNow: 100),
        isFalse,
      );
      expect(await db.draft('a', 'peer'), '');
      expect(await db.messages('a', 'peer'), isEmpty);
      expect(await db.draft('b', 'peer'), 'other family');
      await db.saveDraft('a', 'peer', 'new edit', serverNow: day + 101);
      await db.purge('a', 1000 * day);
      expect(await db.draft('a', 'peer'), 'new edit');
    },
  );

  test(
    'body retention is independent of ticket expiry and preserves only unknown status',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.applyRetention('a', {'revision': 1, 'retention': 'day'});
      await db.addTickets('a', [
        {'id': 'op', 'token': 'signed', 'expiresAt': 1000},
      ]);
      await db.enqueue('a', 'peer', {'text': 'secret'}, 100);
      await db.purge('a', 1000);
      expect(await db.outbox('a'), hasLength(1));
      await db.purge('a', day + 100);
      expect(await db.outbox('a'), isEmpty);
      final markers = await db.outcomeMarkers('a');
      expect(markers, hasLength(1));
      expect(markers.toString(), isNot(contains('secret')));
      expect(markers.toString(), isNot(contains('signed')));
    },
  );
}
