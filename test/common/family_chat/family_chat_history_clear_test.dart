import 'dart:async';
import 'dart:io';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_session.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/family_chat_test_api.dart';

class _HistoryApi extends FamilyChatTestApi {
  _HistoryApi() : super('child');
  int generation = 0;
  int? staleConfig;
  bool loseResponse = false;
  bool conflict = false;
  final attempts = <Map<String, Object?>>[];
  final receipts = <Object?, int>{};

  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) async {
    if (operation == 'getFamilyChatConfig') {
      return {
        ...await super.call(operation, data, allowRequest: allowRequest),
        'historyGeneration': staleConfig ?? generation,
      };
    }
    if (operation == 'fetchFamilyChatConversations' && unreadByTarget != null) {
      return {
        ...await super.call(operation, data, allowRequest: allowRequest),
        'historyGeneration':
            conversationSummaryOverrides['historyGeneration'] ?? generation,
      };
    }
    if (operation != 'clearFamilyChatHistory') {
      return super.call(operation, data, allowRequest: allowRequest);
    }
    // Same contract as the transport: admission runs before dispatch.
    if (allowRequest != null && !await allowRequest()) {
      rejectedOperations.add(operation);
      throw const CallableFailure('cancelled');
    }
    dispatchedOperations.add(operation);
    attempts.add(Map.of(data));
    if (conflict) {
      conflict = false;
      generation++;
    }
    final id = data['operationId'];
    final previous = receipts[id];
    if (previous != null) return {'generation': previous};
    if (data['expectedGeneration'] != generation) {
      throw const CallableFailure('rejected', rejectionCode: 'already-exists');
    }
    receipts[id] = ++generation;
    if (loseResponse) throw const CallableFailure('unavailable');
    return {'generation': generation};
  }
}

Map<String, dynamic> _message(String id, int generation, int sequence) => {
  'id': id,
  'conversationId': 'family',
  'senderUid': 'mom',
  'participants': {'child': 'e', 'mom': 'p'},
  'sentAt': DateTime.now().millisecondsSinceEpoch,
  'sequence': sequence,
  'historyGeneration': generation,
  'kind': 'text',
  'text': id,
  'receipts': {'child': {}},
};

FamilyChatSession _session(_HistoryApi api, FamilyChatDatabase database) =>
    FamilyChatSession(
      uid: api.uid,
      api: api,
      db: database,
      isCurrentAccount: () => true,
    );

void main() {
  test(
    'lost clear response survives SQLite restart and rejects old writes',
    () async {
      final directory = Directory.systemTemp.createTempSync('chat-history-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/chat.sqlite');
      final firstDb = FamilyChatDatabase(NativeDatabase(file));
      final api = _HistoryApi()..messages.add(_message('old', 0, 1));
      final first = _session(api, firstDb);
      await first.start();
      final scope = first.scope!;
      expect(first.messages('family').single['id'], 'old');
      await first.saveDraft('family', 'private draft');
      final now = first.serverNow;
      final signed = await firstDb.enqueue(scope, 'family', {
        'kind': 'text',
        'text': 'waiting for a result',
      }, now);
      expect(signed, isNotNull);
      await firstDb.enqueueUnsignedComposerMessage(scope, 'queued', 'mom', {
        'kind': 'text',
        'text': 'waiting for a ticket',
        '_admission': {'accountOffGeneration': 0, 'familyOffGeneration': 0},
      }, now);
      await firstDb.setMetadata('outcome:$scope:prior', {
        'id': 'prior',
        'state': 'unknown',
        'target': 'family',
        'createdAt': now,
      });
      await firstDb.setMetadata('chatOpen', {'scope': scope});
      await firstDb.rememberNotification(scope, 1, 'stamp', tag: 'notice');
      api.loseResponse = true;
      first.stageDraft('family', 'edited private draft');
      await first.clearHistory(scope, 0);
      await first.saveDraft('family', 'edited private draft', edited: false);
      await first.synchronize();
      expect(first.historyClearPending, isTrue);
      expect(first.messages('family').map((m) => m['id']), [signed, 'prior']);
      expect(first.draft('family'), 'edited private draft');
      expect(await firstDb.draft(scope, 'family'), 'edited private draft');
      expect(await firstDb.metadata('chatOpen'), isNull);
      expect(await firstDb.historyCancellationIntents(scope), [
        (id: 1, tag: 'notice'),
      ]);
      expect(
        await firstDb.saveMessage(scope, 'family', _message('late', 0, 1)),
        isFalse,
      );
      first.dispose();
      await firstDb.close();

      final db = FamilyChatDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final notices = await db.historyCancellationIntents(scope);
      expect(notices, [(id: 1, tag: 'notice')]);
      // The platform acknowledges cancellation before fenced admission.
      await db.confirmCancelled(notices.single);
      final next = _session(api, db);
      addTearDown(next.dispose);
      api.offlineConfig = true;
      await next.start();
      expect(next.historyClearPending, isTrue);
      expect(next.messages('family').map((m) => m['id']), [signed, 'prior']);
      expect(next.messages('mom').single['id'], 'queued');
      expect(next.draft('family'), 'edited private draft');
      expect(api.attempts, hasLength(1));
      api.offlineConfig = false;
      api.messages.add(_message('new', 1, 2));
      await next.synchronize();
      expect(api.attempts, [api.attempts.first, api.attempts.first]);
      expect(api.generation, 1);
      expect(next.historyClearPending, isFalse);
      expect(next.messages('family').map((m) => m['id']), [
        'new',
        signed,
        'prior',
      ]);
      expect(api.sendPayloads.map((body) => body['text']), [
        'waiting for a ticket',
      ]);

      api.staleConfig = 0;
      await next.synchronize();
      expect(next.config?['historyGeneration'], 1);
      expect(next.messages('family').map((m) => m['id']), [
        'new',
        signed,
        'prior',
      ]);
    },
  );

  test('clear persists before an older config request completes', () async {
    final directory = Directory.systemTemp.createTempSync('chat-history-held-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/chat.sqlite');
    final firstDb = FamilyChatDatabase(NativeDatabase(file));
    final api = _HistoryApi()..messages.add(_message('old', 0, 1));
    final first = _session(api, firstDb);
    await first.start();
    final scope = first.scope!;
    api
      ..heldOperation = 'getFamilyChatConfig'
      ..operationEntered = Completer<void>()
      ..operationRelease = Completer<void>();
    final earlierSync = first.synchronize();
    await api.operationEntered!.future;
    await first.clearHistory(scope, 0);
    expect(first.historyClearPending, isTrue);
    expect(first.messages('family'), isEmpty);
    expect(api.attempts, isEmpty);
    first.dispose();
    await firstDb.close();

    final db = FamilyChatDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final restarted = _session(api, db);
    addTearDown(restarted.dispose);
    api.offlineConfig = true;
    await restarted.start();
    expect(restarted.historyClearPending, isTrue);
    expect(restarted.messages('family'), isEmpty);
    expect((await db.historyState(scope))['minimum'], 1);
    api.operationRelease!.complete();
    await earlierSync;
    expect(api.attempts, isEmpty);
  });

  test(
    'a late old-generation summary cannot restore a cleared badge',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _HistoryApi()..unreadByTarget = {'family': true};
      final session = _session(api, db);
      addTearDown(session.dispose);
      await session.start();
      expect(session.hasUnreadIn('family'), isTrue);
      api
        ..heldOperation = 'fetchFamilyChatConversations'
        ..operationEntered = Completer<void>()
        ..operationRelease = Completer<void>();
      final sync = session.synchronize();
      await api.operationEntered!.future;
      await session.clearHistory(session.scope!, 0);
      expect(session.hasUnreadIn('family'), isNull);
      api.conversationSummaryOverrides['historyGeneration'] = 0;
      api.operationRelease!.complete();
      await sync;
      expect(api.generation, 1);
      expect(session.hasUnreadIn('family'), isNull);

      api.conversationSummaryOverrides.clear();
      api.unreadByTarget!['family'] = false;
      await session.synchronize();
      expect(session.hasUnreadIn('family'), isFalse);
    },
  );

  test(
    'a settings observation hides history while the session HTTP is held',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _HistoryApi()..messages.add(_message('old', 0, 1));
      final session = _session(api, db);
      addTearDown(session.dispose);
      await session.start();
      expect(session.messages('family').single['id'], 'old');
      api
        ..heldOperation = 'getFamilyChatConfig'
        ..operationEntered = Completer<void>()
        ..operationRelease = Completer<void>();
      final sync = session.synchronize();
      await api.operationEntered!.future;
      final confirmed = {
        'uid': api.uid,
        'familyId': 'f',
        'epoch': api.epoch,
        'historyGeneration': 1,
      };
      session.reconcileConfirmedHistory({...confirmed, 'uid': 'other'});
      session.reconcileConfirmedHistory({...confirmed, 'epoch': 'other'});
      expect(session.messages('family').single['id'], 'old');
      await db.observeHistoryGeneration(session.scope!, 1);
      session.reconcileConfirmedHistory(confirmed);
      expect(session.messages('family'), isEmpty);
      api.operationRelease!.complete();
      await sync;
      expect(session.messages('family'), isEmpty);
      expect(await db.message(session.scope!, 'old'), isNull);
    },
  );

  test(
    'CAS conflict requires a fresh gesture and never rebases the operation',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _HistoryApi()..messages.add(_message('old', 0, 1));
      final session = _session(api, db);
      addTearDown(session.dispose);
      await session.start();
      final scope = session.scope!;
      api.conflict = true;
      await session.clearHistory(scope, 0);
      await session.synchronize();
      expect(session.historyClearConflict, isTrue);
      expect(session.canClearHistory, isFalse);
      expect(session.messages('family'), isEmpty);
      await session.synchronize();
      expect(session.canClearHistory, isTrue);
      expect(api.attempts, hasLength(1));
      await expectLater(session.clearHistory(scope, 0), throwsStateError);
      await session.clearHistory(scope, 1);
      await session.synchronize();
      expect(api.attempts, hasLength(2));
      expect(
        api.attempts.first['operationId'],
        isNot(api.attempts.last['operationId']),
      );
      expect(api.generation, 2);
      expect(session.historyClearConflict, isFalse);
    },
  );

  test(
    'OFF pauses a retained intent and an epoch change discards it',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _HistoryApi();
      final session = _session(api, db);
      addTearDown(session.dispose);
      await session.start();
      final scope = session.scope!;
      api.loseResponse = true;
      await session.clearHistory(scope, 0);
      await session.synchronize();
      api.accountEnabled = false;
      await session.synchronize();
      expect(session.enabled, isFalse);
      expect((await db.historyState(scope))['intent'], isNotNull);
      expect(api.attempts, hasLength(1));
      api
        ..accountEnabled = true
        ..generation = 0
        ..epoch = 'new-epoch';
      await session.synchronize();
      expect(session.enabled, isTrue);
      expect(await db.historyState(scope), isEmpty);
      expect(api.attempts, hasLength(1));
    },
  );
}
