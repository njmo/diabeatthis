import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_session.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_remote.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

class _Api implements FamilyChatApi {
  int now = 1000000;
  int ticket = 0;
  int sends = 0;
  bool failAfterCommit = true;
  bool offline = false;
  bool authUnavailable = false;
  bool sendAuthUnavailable = false;
  bool ackAuthUnavailable = false;
  int acknowledgements = 0;
  final rows = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) async {
    if (allowRequest != null && !await allowRequest()) {
      throw const CallableFailure('cancelled');
    }
    if (offline) throw const CallableFailure('unavailable');
    if (authUnavailable) throw const CallableFailure('unauthenticated');
    switch (operation) {
      case 'fetchFamilyChatShortcuts':
        return {'items': null, 'revision': 0, 'order': [], 'orderRevision': 0};
      case 'getFamilyChatConfig':
        return {
          'uid': 'child',
          'familyId': 'f',
          'epoch': 'e',
          'serverTime': now,
          'account': {'enabled': true, 'revision': 0},
          'policy': {
            'enabled': true,
            'retention': 'week',
            'revision': 0,
            'shortenings': [],
          },
          'members': [
            {'uid': 'child', 'role': 'child', 'displayName': 'Dziecko'},
            {
              'uid': 'mom',
              'role': 'managingCaregiver',
              'displayName': 'Opiekun',
            },
          ],
        };
      case 'fetchFamilyChatConversations':
        return {'conversations': [], 'hasMore': false, 'cursor': ''};
      case 'fetchFamilyChatMessageStates':
        return {
          'messages': rows
              .where((row) => (data['ids'] as List).contains(row['id']))
              .toList(),
          'missing': <String>[],
        };
      case 'fetchFamilyChatMessages':
        return {
          'messages': data['targetUid'] == 'mom'
              ? rows
                    .where(
                      (row) =>
                          (row['sequence'] as int) >
                          (data['after'] as int? ?? 0),
                    )
                    .toList()
              : [],
          'cursor': data['targetUid'] == 'mom' && rows.isNotEmpty
              ? rows.last['sequence']
              : data['after'] ?? 0,
          'hasMore': false,
        };
      case 'reserveFamilyChatOperations':
        return {
          'tickets': [
            for (var i = 0; i < (data['count'] as int); i++)
              {
                'id': 'op${++ticket}',
                'token': 'op$ticket',
                'expiresAt': now + 86400000,
              },
          ],
        };
      case 'sendFamilyChatMessage':
        if (sendAuthUnavailable) {
          throw const CallableFailure(
            'unavailable',
            rejectionCode: 'unauthenticated',
          );
        }
        sends++;
        final message = {
          'id': data['ticket'],
          'text': data['text'],
          'kind': data['kind'],
          'answers': data['answers'],
          'senderUid': 'child',
          'sequence': 1,
          'sentAt': now,
          'expiresAt': now + 86400000,
          'policyRevision': 0,
          'receipts': {
            'mom': {'deliveredAt': null, 'readAt': null},
          },
        };
        rows.add(message);
        if (failAfterCommit) throw const CallableFailure('unavailable');
        return {'message': message};
      case 'acknowledgeFamilyChatMessages':
        if (ackAuthUnavailable) {
          throw const CallableFailure(
            'unavailable',
            rejectionCode: 'unauthenticated',
          );
        }
        acknowledgements++;
        return {
          'acknowledged': (data['items'] as List)
              .map((item) => item['messageId'])
              .toList(),
          'ignored': <String>[],
        };
    }
    throw StateError(operation);
  }
}

class _DelayedDb extends FamilyChatDatabase {
  _DelayedDb() : super(NativeDatabase.memory());
  bool hold = false;
  final entered = Completer<void>();
  final released = Completer<void>();
  @override
  Future<bool> saveMessage(
    String scope,
    String target,
    Map<String, dynamic> message, {
    int? serverNow,
  }) async {
    if (hold) {
      entered.complete();
      await released.future;
    }
    return super.saveMessage(scope, target, message, serverNow: serverNow);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'v1 database migrates in place without losing messages, outbox or drafts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'family-chat-v1-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/chat.sqlite');
      final raw = sqlite3.open(file.path);
      raw.execute(
        'CREATE TABLE chat_metadata (key TEXT PRIMARY KEY,value TEXT NOT NULL)',
      );
      raw.execute(
        'CREATE TABLE chat_messages (scope TEXT NOT NULL,target TEXT NOT NULL,id TEXT NOT NULL,payload TEXT NOT NULL,expires_at INTEGER,PRIMARY KEY(scope,id))',
      );
      raw.execute(
        'CREATE TABLE chat_outbox (scope TEXT NOT NULL,id TEXT NOT NULL,target TEXT NOT NULL,payload TEXT NOT NULL,expires_at INTEGER NOT NULL,created_at INTEGER NOT NULL,error TEXT,PRIMARY KEY(scope,id))',
      );
      raw.execute(
        'CREATE TABLE chat_drafts (scope TEXT NOT NULL,target TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(scope,target))',
      );
      raw.execute(
        'CREATE TABLE chat_actions (scope TEXT NOT NULL,id TEXT NOT NULL,is_read INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(scope,id))',
      );
      raw.execute(
        'CREATE TABLE chat_tickets (scope TEXT NOT NULL,id TEXT NOT NULL,token TEXT NOT NULL,expires_at INTEGER NOT NULL,PRIMARY KEY(scope,id))',
      );
      raw.execute('INSERT INTO chat_messages VALUES (?,?,?,?,?)', [
        'scope',
        'peer',
        'message',
        jsonEncode({'id': 'message', 'text': 'Saved', 'sequence': 1}),
        null,
      ]);
      raw.execute('INSERT INTO chat_outbox VALUES (?,?,?,?,?,?,?)', [
        'scope',
        'operation',
        'peer',
        jsonEncode({'text': 'Queued'}),
        9999999999999,
        10,
        null,
      ]);
      raw.execute('INSERT INTO chat_drafts VALUES (?,?,?)', [
        'scope',
        'peer',
        'Draft',
      ]);
      raw.execute('PRAGMA user_version=1');
      raw.dispose();
      final db = FamilyChatDatabase(NativeDatabase(file));
      expect((await db.messages('scope', 'peer')).single['text'], 'Saved');
      expect(
        (await db.outbox('scope')).single.read<String>('payload'),
        contains('Queued'),
      );
      expect(await db.draft('scope', 'peer'), 'Draft');
      await db.queueReceipt('scope', 'message', true);
      expect((await db.messages('scope', 'peer')).single['_localRead'], isTrue);
      await db.close();
    },
  );
  test(
    'invalidate waits for old database writes and leaves no stale account state',
    () async {
      final db = _DelayedDb();
      addTearDown(db.close);
      final api = _Api();
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
        clock: () => DateTime.fromMillisecondsSinceEpoch(api.now),
      );
      addTearDown(session.dispose);
      await session.start();
      final oldScope = session.scope!;
      await session.saveDraft('mom', 'Secret draft');
      api.rows.add({
        'id': 'remote',
        'text': 'Private',
        'kind': 'text',
        'senderUid': 'mom',
        'sequence': 1,
        'sentAt': api.now,
        'expiresAt': api.now + 86400000,
        'receipts': {
          'child': {'deliveredAt': null, 'readAt': null},
        },
      });
      db.hold = true;
      final syncing = session.synchronize();
      await db.entered.future;
      final clearing = session.invalidate();
      expect(session.draft('mom'), '');
      expect(session.config, isNull);
      expect(session.members, isEmpty);
      expect(session.threads, isEmpty);
      db.released.complete();
      await Future.wait([syncing, clearing]);
      expect(session.active, isFalse);
      expect(session.config, isNull);
      expect(session.messages('mom'), isEmpty);
      expect(await db.messages(oldScope, 'mom'), isEmpty);
      expect(await db.metadata('account:child'), isNull);
    },
  );
  test(
    'local expiry works while remaining offline and temporary auth failure preserves outbox',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api()..failAfterCommit = false;
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
        clock: () => DateTime.fromMillisecondsSinceEpoch(api.now),
      );
      addTearDown(session.dispose);
      await session.start();
      await session.send('mom', 'Will expire');
      await session.synchronize();
      api.offline = true;
      api.now += 2 * 86400000;
      await session.synchronize();
      expect(session.messages('mom'), isEmpty);
      api.offline = false;
      await session.synchronize();
      api.offline = true;
      await session.send('mom', 'Keep my draft');
      await session.synchronize();
      final oldScope = session.scope!;
      api.offline = false;
      api.authUnavailable = true;
      await session.synchronize();
      expect(session.enabled, isFalse);
      expect(await db.outbox(oldScope), hasLength(1));
      api.authUnavailable = false;
      await session.synchronize();
      expect(session.enabled, isTrue);
      expect(await db.outbox(oldScope), isEmpty);
    },
  );
  test(
    'expired tickets remain outcome-unknown and deletion keeps only a minimal status marker',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.addTickets('scope', [
        {'id': 'one', 'token': 'ticket', 'expiresAt': 100},
      ]);
      await db.enqueue('scope', 'peer', {
        'text': 'Keep for explicit resend',
      }, 10);
      await db.purge('scope', 101);
      final operation = (await db.outbox('scope')).single;
      expect(operation.read<String>('error'), 'send-outcome-unknown');
      expect(
        operation.read<String>('payload'),
        contains('Keep for explicit resend'),
      );
      await db.purge('scope', 604800101);
      expect(await db.outbox('scope'), isEmpty);
      final marker = await db.metadata('outcome:scope:one');
      expect(marker?['state'], 'unknown');
      expect(jsonEncode(marker), isNot(contains('Keep for explicit resend')));
      expect(jsonEncode(marker), isNot(contains('ticket')));
      await db.clearScope('scope');
      expect(await db.metadata('outcome:scope:one'), isNull);
    },
  );
  test(
    'auth expiring during send and receipt flush preserves both operations for recovery',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api()..failAfterCommit = false;
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
        clock: () => DateTime.fromMillisecondsSinceEpoch(api.now),
      );
      addTearDown(session.dispose);
      await session.start();
      final currentScope = session.scope!;
      api.sendAuthUnavailable = true;
      await session.send('mom', 'Keep outgoing');
      await session.synchronize();
      expect(await db.outbox(currentScope), hasLength(1));
      expect(session.enabled, isFalse);
      api.sendAuthUnavailable = false;
      await session.synchronize();
      expect(await db.outbox(currentScope), isEmpty);
      await db.queueReceipt(currentScope, 'received', true);
      api.ackAuthUnavailable = true;
      await session.synchronize();
      expect(await db.receipts(currentScope), hasLength(1));
      api.ackAuthUnavailable = false;
      await session.synchronize();
      expect(await db.receipts(currentScope), isEmpty);
      expect(api.acknowledgements, 1);
    },
  );
  test(
    'clock rollback hides history without deleting drafts and queued messages',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api()..failAfterCommit = false;
      var localNow = api.now;
      var session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
        clock: () => DateTime.fromMillisecondsSinceEpoch(localNow),
      );
      await session.start();
      api.offline = true;
      await session.send('mom', 'Queued');
      await session.synchronize();
      await session.saveDraft('mom', 'Still typing');
      final currentScope = session.scope!;
      session.dispose();
      localNow -= 60000;
      session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
        clock: () => DateTime.fromMillisecondsSinceEpoch(localNow),
      );
      await session.start();
      expect(session.messages('mom'), isEmpty);
      expect(session.draft('mom'), '');
      expect(await db.outbox(currentScope), hasLength(1));
      expect(await db.draft(currentScope, 'mom'), 'Still typing');
      api.offline = false;
      await session.synchronize();
      expect(session.enabled, isTrue);
      expect(await db.outbox(currentScope), isEmpty);
      expect(session.draft('mom'), 'Still typing');
      session.dispose();
    },
  );
  test(
    'timeout after server commit recovers after a real database reopen without resending',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'family-chat-db-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/chat.sqlite');
      final api = _Api();
      var db = FamilyChatDatabase(NativeDatabase(file));
      var session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
        clock: () => DateTime.fromMillisecondsSinceEpoch(api.now),
      );
      await session.start();
      await session.saveDraft('mom', 'Hello');
      await session.send('mom', 'Hello', composerDraft: 'Hello');
      expect(await db.draft(session.scope!, 'mom'), '');
      await session.synchronize();
      expect(api.sends, 1);
      expect(session.messages('mom').single['delivery'], 'pending');
      session.dispose();
      await db.close();
      db = FamilyChatDatabase(NativeDatabase(file));
      session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
        clock: () => DateTime.fromMillisecondsSinceEpoch(api.now),
      );
      await session.start();
      expect(api.sends, 1);
      expect(session.messages('mom').single['text'], 'Hello');
      expect(await db.outbox(session.scope!), isEmpty);
      await session.invalidate();
      expect(await db.metadata('account:child'), isNull);
      expect(
        await db.messages(jsonEncode(['child', 'f', 'e']), 'mom'),
        isEmpty,
      );
      session.dispose();
      await db.close();
    },
  );

  test(
    'receipt upgrade survives an in-flight delivered ACK and account cleanup stays isolated',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final scope = jsonEncode(['a_b', 'family', 'epoch']);
      final other = jsonEncode(['axb', 'family', 'epoch']);
      await db.queueReceipt(scope, 'message', false);
      await db.queueReceipt(scope, 'message', true);
      await db.queueReceipt(scope, 'message', false);
      await db.completeReceipt(scope, 'message', false);
      expect((await db.receipts(scope)).single.read<int>('is_read'), 1);
      await db.saveDraft(scope, 'peer', 'secret one');
      await db.saveDraft(other, 'peer', 'secret two');
      await db.setMetadata('cursor:$scope:peer', {'value': 5});
      await db.setMetadata('cursor:$other:peer', {'value': 7});
      await db.clearAccount('a_b');
      expect(await db.draft(scope, 'peer'), '');
      expect(await db.draft(other, 'peer'), 'secret two');
      expect(await db.metadata('cursor:$other:peer'), {'value': 7});
    },
  );

  test(
    'offline reopen advances expiry instead of resetting time to the last server timestamp',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api()..failAfterCommit = false;
      var session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
        clock: () => DateTime.fromMillisecondsSinceEpoch(api.now),
      );
      await session.start();
      await session.send('mom', 'Expires');
      await session.synchronize();
      session.dispose();
      api.now += 2 * 86400000;
      api.offline = true;
      session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
        clock: () => DateTime.fromMillisecondsSinceEpoch(api.now),
      );
      await session.start();
      expect(session.messages('mom'), isEmpty);
      session.dispose();
    },
  );
}
