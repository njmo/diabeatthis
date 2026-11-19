import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_session.dart';
import 'package:diabeatthis/common/family_chat/application/queue_family_chat_message.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_guard_fence.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_remote.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

const _day = 86400000;
const _scope = '["parent","family-id","epoch"]';

class _Api implements FamilyChatApi {
  bool online = true;
  bool issueTickets = true;
  bool loseSend = false;
  int now = 1000000;
  int offGeneration = 0;
  String epoch = 'epoch';
  int nextTicket = 0;
  final calls = <({String name, Map<String, Object?> data})>[];

  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) async {
    if (allowRequest != null && !await allowRequest()) {
      throw const CallableFailure('cancelled');
    }
    calls.add((name: operation, data: data));
    if (!online) throw const CallableFailure('unavailable');
    switch (operation) {
      case 'getFamilyChatConfig':
        return {
          'uid': 'parent',
          'familyId': 'family-id',
          'epoch': epoch,
          'serverTime': now,
          'account': {
            'enabled': true,
            'revision': offGeneration,
            'offGeneration': offGeneration,
          },
          'policy': {'enabled': true, 'revision': 0, 'retention': 'day'},
          'members': [
            {'uid': 'parent', 'role': 'managingCaregiver'},
            {'uid': 'child', 'role': 'child'},
          ],
        };
      case 'fetchFamilyChatConversations':
        return {'conversations': [], 'hasMore': false, 'cursor': ''};
      case 'fetchFamilyChatMessages':
        return {'messages': [], 'cursor': 0, 'hasMore': false};
      case 'fetchFamilyChatMessageStates':
        return {'messages': []};
      case 'reserveFamilyChatOperations':
        return {
          'tickets': [
            if (issueTickets)
              for (var i = 0; i < (data['count'] as int); i++)
                {
                  'id': 'signed-${++nextTicket}',
                  'token': 'token-$nextTicket',
                  'expiresAt': now + _day,
                },
          ],
        };
      case 'sendFamilyChatMessage':
        if (loseSend) throw const CallableFailure('unavailable');
        return {
          'message': {
            'id': 'signed-${(data['ticket'] as String).split('-').last}',
            'senderUid': 'parent',
            'kind': data['kind'],
            'text': data['text'],
            'sentAt': now,
            'sequence': 1,
            'expiresAt': now + _day,
          },
        };
      case 'fetchFamilyChatShortcuts':
        return {'items': [], 'revision': 0, 'order': [], 'orderRevision': 0};
      default:
        throw StateError(operation);
    }
  }

  List<Map<String, Object?>> sent() => [
    for (final call in calls)
      if (call.name == 'sendFamilyChatMessage') call.data,
  ];
}

FamilyChatSession _session(_Api api, FamilyChatDatabase db) =>
    FamilyChatSession(
      uid: 'parent',
      api: api,
      db: db,
      isCurrentAccount: () => true,
      clock: () => DateTime.fromMillisecondsSinceEpoch(api.now),
    );

void main() {
  test(
    'offline composer queues text, question and answer durably without HTTP',
    () async {
      final directory = await Directory.systemTemp.createTemp('offline-chat-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/chat.db');
      final api = _Api();
      final initialDb = FamilyChatDatabase(NativeDatabase(file));
      final initial = _session(api, initialDb);
      await initial.start();
      initial.dispose();
      await initialDb.close();

      api.online = false;
      final offlineDb = FamilyChatDatabase(NativeDatabase(file));
      final offline = _session(api, offlineDb);
      await offline.start();
      expect(offline.serverVerified, false);
      expect(offline.canQueueComposer, true);
      api.calls.clear();

      await offline.saveDraft('child', 'Offline text');
      await offline.send(
        'child',
        'Offline text',
        composerDraft: 'Offline text',
      );
      await offline.send(
        'child',
        'A question?',
        kind: 'question',
        answers: ['Yes'],
      );
      await offline.send(
        'child',
        'Yes',
        kind: 'answer',
        replyTo: 'existing-question',
      );

      expect(api.calls, isEmpty);
      expect(offline.draft('child'), '');
      expect(await offlineDb.draft(_scope, 'child'), '');
      final unsigned = await offlineDb.outbox(_scope);
      expect(unsigned, hasLength(3));
      expect(
        unsigned.every(
          (row) => row.read<String>('error') == familyChatAwaitingTicket,
        ),
        true,
      );
      expect(
        offline.messages('child').map((message) => message['delivery']),
        everyElement('pending'),
      );

      final originalId = unsigned.first.read<String>('id');
      final originalDeadline = unsigned.first.read<int>('retention_until');
      offline.dispose();
      await offlineDb.close();

      final recoveredDb = FamilyChatDatabase(NativeDatabase(file));
      addTearDown(recoveredDb.close);
      final recovered = _session(api, recoveredDb);
      addTearDown(recovered.dispose);
      await recovered.start();
      expect(recovered.messages('child').map((message) => message['text']), [
        'Offline text',
        'A question?',
        'Yes',
      ]);
      expect(recovered.draft('child'), '');

      await recoveredDb.enqueueUnsentReply(
        _scope,
        'watch-local',
        'child',
        {
          'kind': 'answer',
          'replyTo': 'existing-question',
          'text': 'Watch draft',
        },
        api.now,
        'notificationReply:test',
      );

      api.calls.clear();
      api.online = true;
      api.loseSend = true;
      api.now += 1000;
      await recovered.synchronize();
      final firstTicket = api.sent().single['ticket'];
      final promoted = (await recoveredDb.outbox(_scope)).first;
      expect(promoted.read<int>('retention_until'), originalDeadline);
      expect(
        promoted.read<int>('created_at'),
        unsigned.first.read<int>('created_at'),
      );
      expect(promoted.readNullable<String>('error'), isNull);
      expect(
        jsonEncode(api.calls.map((call) => call.data).toList()),
        isNot(contains(originalId)),
      );

      api.loseSend = false;
      await recovered.synchronize();
      expect(api.sent().map((send) => send['text']), [
        'Offline text',
        'Offline text',
        'A question?',
        'Yes',
      ]);
      expect(api.sent()[1]['ticket'], firstTicket);
      expect(api.sent().any((send) => send.containsKey('_admission')), false);
      expect(api.sent().last['replyTo'], 'existing-question');
      expect(
        (await recoveredDb.outbox(_scope)).single.read<String>('error'),
        'needs-ticket',
      );
    },
  );

  test(
    'cached composer capability requires matching scope, clock and local consent',
    () async {
      final api = _Api();
      final fence = MemoryChatGuardFence();
      final db = FamilyChatDatabase(NativeDatabase.memory(), fence);
      addTearDown(db.close);
      final first = _session(api, db);
      await first.start();
      expect(first.canQueueComposer, true);
      first.dispose();
      final cachedConfig = (await db.metadata('account:parent'))!;
      api.online = false;

      for (final changes in [
        {'uid': 'different-account'},
        {'epoch': 'different-epoch'},
        {'_observedLocalAt': api.now + _day},
      ]) {
        await db.setMetadata('account:parent', {...cachedConfig, ...changes});
        final cached = _session(api, db);
        await cached.start();
        expect(cached.canQueueComposer, false, reason: changes.toString());
        cached.dispose();
      }

      await db.setMetadata('account:parent', cachedConfig);
      await fence.revokeAccount('parent');
      final revoked = _session(api, db);
      addTearDown(revoked.dispose);
      await revoked.start();
      expect(revoked.canQueueComposer, false);
      await expectLater(revoked.send('child', 'Not allowed'), throwsStateError);
    },
  );

  test(
    'home retries only queued work and reconnect restarts its bounded window',
    () {
      fakeAsync((time) {
        final api = _Api()..issueTickets = false;
        final db = FamilyChatDatabase(NativeDatabase.memory());
        final session = _session(api, db);
        unawaited(session.start());
        time.flushMicrotasks();
        expect(session.canQueueComposer, true);
        session.setForeground(true, chatVisible: false);
        api.calls.clear();
        time.elapse(const Duration(minutes: 1));
        expect(api.calls, isEmpty);

        api.online = false;
        unawaited(session.send('child', 'Send me after reconnect'));
        time.flushMicrotasks();
        expect(api.calls, isEmpty);
        time.elapse(const Duration(minutes: 2));
        expect(
          api.calls.map((call) => call.name),
          List.filled(5, 'getFamilyChatConfig'),
        );
        api.calls.clear();
        time.elapse(const Duration(minutes: 10));
        expect(api.calls, isEmpty);

        api.online = true;
        api.issueTickets = true;
        session.resumeQueuedSends();
        time.flushMicrotasks();
        expect(api.sent().single['text'], 'Send me after reconnect');
        api.calls.clear();
        time.elapse(const Duration(minutes: 2));
        expect(api.calls, isEmpty);
        session.dispose();
        unawaited(db.close());
        time.flushMicrotasks();
      });
    },
  );

  test(
    'home retry stops in background and invalidate discards pending work',
    () {
      fakeAsync((time) {
        final api = _Api()..issueTickets = false;
        final db = FamilyChatDatabase(NativeDatabase.memory());
        final session = _session(api, db);
        unawaited(session.start());
        time.flushMicrotasks();
        session.setForeground(true, chatVisible: false);
        unawaited(session.send('child', 'Pending'));
        time.flushMicrotasks();
        api.calls.clear();

        session.setForeground(false, chatVisible: false);
        session.resumeQueuedSends();
        time.elapse(const Duration(minutes: 1));
        expect(api.calls, isEmpty);
        api.issueTickets = true;
        session.setForeground(true, chatVisible: false);
        time.flushMicrotasks();
        expect(api.sent().single['text'], 'Pending');

        api.issueTickets = false;
        unawaited(session.send('child', 'Do not send after OFF'));
        time.flushMicrotasks();
        api.calls.clear();
        unawaited(session.invalidate());
        time.flushMicrotasks();
        session.resumeQueuedSends();
        time.elapse(const Duration(minutes: 2));
        expect(session.canQueueComposer, false);
        expect(api.calls, isEmpty);
        session.dispose();
        unawaited(db.close());
        time.flushMicrotasks();
      });
    },
  );

  for (final invalidation in ['retention', 'consent', 'epoch']) {
    test(
      'fresh synchronization drops unsigned message after $invalidation changes',
      () async {
        final api = _Api()..issueTickets = false;
        final db = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final session = _session(api, db);
        addTearDown(session.dispose);
        await session.start();
        api.calls.clear();
        await session.send('child', 'Old submission');
        expect(api.calls, isEmpty);
        expect(await db.outbox(_scope), hasLength(1));

        api.issueTickets = true;
        switch (invalidation) {
          case 'retention':
            api.now += _day + 10000;
          case 'consent':
            api.offGeneration++;
          case 'epoch':
            api.epoch = 'new-epoch';
        }
        await session.synchronize();
        expect(api.sent(), isEmpty);
        expect(await db.outbox(_scope), isEmpty);
        expect(await db.outcomeMarkers(_scope), isEmpty);
      },
    );
  }

  test(
    'a fence transition during admission rolls back the queue and composer clear',
    () async {
      final fence = MemoryChatGuardFence();
      final db = FamilyChatDatabase(NativeDatabase.memory(), fence);
      addTearDown(db.close);
      final version = (await fence.read())['version'] as String;
      await fence.activate(version, 'parent', _scope, 'stamp');
      await db.saveDraft(_scope, 'child', 'Keep me', serverNow: 1000000);

      final result = await QueueFamilyChatMessage(db)(
        uid: 'parent',
        scope: _scope,
        target: 'child',
        expectedVersion: version,
        expectedStamp: 'stamp',
        allowed: () => true,
        preferSigned: false,
        allowUnsigned: true,
        payload: {'kind': 'text', 'text': 'Keep me'},
        accountOffGeneration: 0,
        familyOffGeneration: 0,
        now: () => 1000000,
        clearSubmittedDraft: () {
          // Production OFF revokes the independent fence even under the writer.
          fence.revokeAccount('parent');
          return true;
        },
      );

      expect(result, isNull);
      expect(await db.outbox(_scope), isEmpty);
      expect(await db.draft(_scope, 'child'), 'Keep me');
    },
  );

  test(
    'matching text with a newer edit revision stays in the composer',
    () async {
      final api = _Api()..issueTickets = false;
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final session = _session(api, db);
      addTearDown(session.dispose);
      await session.start();
      await session.saveDraft('child', 'Same text');
      final send = session.send(
        'child',
        'Same text',
        composerDraft: 'Same text',
      );
      session.stageDraft('child', 'Different edit');
      await session.saveDraft('child', 'Same text');
      await send;
      expect(session.draft('child'), 'Same text');
      expect(await db.draft(_scope, 'child'), 'Same text');
      expect(await db.outbox(_scope), hasLength(1));
    },
  );
}
