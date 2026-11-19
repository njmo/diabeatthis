import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_chat/application/confirm_family_treatment.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_runtime.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_session.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_remote.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/family_treatment_journal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/family_chat_test_api.dart';

/// Holds the durable history read inside allowRequest once armed.
class _GatedHistoryDb extends FamilyChatDatabase {
  _GatedHistoryDb() : super(NativeDatabase.memory());
  Completer<void>? historyEntered, historyRelease;
  @override
  Future<bool> historyAllows(String scope, int generation) async {
    final release = historyRelease;
    if (release != null) {
      historyRelease = null;
      historyEntered!.complete();
      await release.future;
    }
    return super.historyAllows(scope, generation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A1: Scope Change & Fresh Admission for Same UID', () {
    test(
      'changed family for same UID synchronously hides old session and fences held HTTP',
      () async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final runtime = FamilyChatRuntime(db)..setForeground(false);
        addTearDown(runtime.dispose);

        final api1 = FamilyChatTestApi('child')
          ..familyId = 'family1'
          ..epoch = 'epoch1';
        final scope1 = jsonEncode(['child', 'family1', 'epoch1']);

        await runtime.update('child', true, api1, scope: scope1);
        final session1 = runtime.session;
        expect(session1, isNotNull);
        expect(session1!.scope, scope1);

        await db.saveMessage(scope1, 'mom', {
          'id': 'm1',
          'senderUid': 'mom',
          'text': 'Old family message',
          'sequence': 1,
        });

        api1
          ..heldOperation = 'fetchFamilyChatConversations'
          ..operationEntered = Completer<void>()
          ..operationRelease = Completer<void>();
        final oldSync = session1.synchronize();
        try {
          await api1.operationEntered!.future;

          final api2 = FamilyChatTestApi('child')
            ..familyId = 'family2'
            ..epoch = 'epoch1';
          final scope2 = jsonEncode(['child', 'family2', 'epoch1']);
          final dispatchedBefore = api1.dispatchedOperations.length;

          final updateFuture = runtime.update(
            'child',
            true,
            api2,
            scope: scope2,
          );

          // Synchronously hidden before any await.
          expect(runtime.session, isNull);
          expect(session1.isInvalidated, isTrue);
          expect(session1.scope, isNull);

          api1.operationRelease!.complete();
          await oldSync;
          await updateFuture;

          // The old session never dispatched anything after release.
          expect(
            api1.dispatchedOperations.skip(dispatchedBefore),
            isNot(contains('fetchFamilyChatConversations')),
          );
          final session2 = runtime.session;
          expect(session2, isNotNull);
          expect(session2!.scope, scope2);
          expect(session2.messages('mom'), isEmpty);
          expect(await db.messages(scope2, 'mom'), isEmpty);
        } finally {
          if (!api1.operationRelease!.isCompleted) {
            api1.operationRelease!.complete();
          }
        }
      },
    );

    test(
      'authoritative fresh getConfig for another scope invalidates and aborts sync',
      () async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final runtime = FamilyChatRuntime(db)..setForeground(false);
        addTearDown(runtime.dispose);
        final api = FamilyChatTestApi('child')
          ..familyId = 'A'
          ..epoch = 'e';
        final scopeA = jsonEncode(['child', 'A', 'e']);

        await runtime.update('child', true, api, scope: scopeA);
        final session = runtime.session!;
        // Runs before runtime.dispose and db.close (LIFO): drain the
        // session's idempotent invalidation cleanup.
        addTearDown(session.invalidate);
        expect(session.scope, scopeA);
        expect(session.enabled, isTrue);

        // Server already moved the account to B; settings have not yet.
        api.familyId = 'B';
        final from = api.dispatchedOperations.length;
        await session.synchronize();

        final after = api.dispatchedOperations.skip(from).toList();
        expect(after, ['getFamilyChatConfig']);
        expect(session.isInvalidated, isTrue);
        expect(session.scope, isNull);
        expect(session.enabled, isFalse);
        expect(session.threads, isEmpty);
        expect(session.messages('mom'), isEmpty);

        // Further sync attempts on the stale session do nothing.
        await session.synchronize();
        expect(api.dispatchedOperations.skip(from).toList(), after);
      },
    );

    test(
      'changed epoch for same UID synchronously invalidates old scope and ignores stale cache',
      () async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final runtime = FamilyChatRuntime(db)..setForeground(false);
        addTearDown(runtime.dispose);

        final api1 = FamilyChatTestApi('child')
          ..familyId = 'family1'
          ..epoch = 'epoch1';
        final scope1 = jsonEncode(['child', 'family1', 'epoch1']);

        await runtime.update('child', true, api1, scope: scope1);
        final session1 = runtime.session!;
        expect(session1.scope, scope1);
        await session1.saveDraft('mom', 'Draft in epoch 1');
        expect(await db.draft(scope1, 'mom'), 'Draft in epoch 1');

        final scope2 = jsonEncode(['child', 'family1', 'epoch2']);
        final api2 = FamilyChatTestApi('child')
          ..familyId = 'family1'
          ..epoch = 'epoch2'
          ..offlineConfig = true;

        final updateFuture = runtime.update('child', true, api2, scope: scope2);
        expect(runtime.session, isNull);
        expect(session1.isInvalidated, isTrue);
        await updateFuture;

        final offlineSession = FamilyChatSession(
          uid: 'child',
          api: api2,
          db: db,
          expectedScope: scope2,
          isCurrentAccount: () => true,
        );
        addTearDown(offlineSession.dispose);
        await offlineSession.start();
        expect(offlineSession.scope, isNull);
        expect(offlineSession.threads, isEmpty);
        expect(offlineSession.draft('mom'), isEmpty);

        api2.offlineConfig = false;
        await offlineSession.synchronize();
        expect(offlineSession.scope, scope2);
        expect(offlineSession.draft('mom'), isEmpty);
      },
    );

    test(
      'reconcileConfirmedScope invalidates active session on mismatch only',
      () async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final api = FamilyChatTestApi('child')
          ..familyId = 'fam1'
          ..epoch = 'ep1';
        final scope1 = jsonEncode(['child', 'fam1', 'ep1']);
        final session = FamilyChatSession(
          uid: 'child',
          api: api,
          db: db,
          expectedScope: scope1,
          isCurrentAccount: () => true,
        );
        addTearDown(session.dispose);
        // Runs first (LIFO): drain the idempotent invalidation cleanup
        // before the database closes.
        addTearDown(session.invalidate);
        await session.start();
        expect(session.scope, scope1);

        session.reconcileConfirmedScope({
          'uid': 'child',
          'familyId': 'fam1',
          'epoch': 'ep1',
        });
        expect(session.isInvalidated, isFalse);

        session.reconcileConfirmedScope({
          'uid': 'child',
          'familyId': 'fam2',
          'epoch': 'ep1',
        });
        expect(session.isInvalidated, isTrue);
        expect(session.scope, isNull);
      },
    );

    test(
      'coldstart held old getConfig -> fresh known new scope -> release old response; repeat same known scope does not reset',
      () async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final runtime = FamilyChatRuntime(db)..setForeground(false);
        addTearDown(runtime.dispose);

        final api1 = FamilyChatTestApi('child')
          ..familyId = 'old-family'
          ..epoch = 'old-epoch'
          ..heldOperation = 'getFamilyChatConfig'
          ..operationEntered = Completer<void>()
          ..operationRelease = Completer<void>();

        final coldStart = runtime.update('child', true, api1);
        try {
          await api1.operationEntered!.future;
          final oldSession = runtime.session;
          expect(oldSession, isNotNull);
          expect(oldSession!.expectedScope, isNull);
          expect(oldSession.scope, isNull);

          final api2 = FamilyChatTestApi('child')
            ..familyId = 'new-family'
            ..epoch = 'new-epoch';
          final newScope = jsonEncode(['child', 'new-family', 'new-epoch']);
          final freshScopeUpdate = runtime.update(
            'child',
            true,
            api2,
            scope: newScope,
          );
          expect(runtime.session, isNull);
          expect(oldSession.isInvalidated, isTrue);

          api1.operationRelease!.complete();
          await coldStart;
          await freshScopeUpdate;
          // The held old-scope response was never admitted.
          expect(oldSession.scope, isNull);
          final newSession = runtime.session;
          expect(newSession, isNotNull);
          expect(newSession!.expectedScope, newScope);
          expect(newSession.scope, newScope);

          final sameScopeUpdate = runtime.update(
            'child',
            true,
            api2,
            scope: newScope,
          );
          expect(runtime.session, same(newSession));
          await sameScopeUpdate;
          // A later non-fresh (unknown scope) settings pass must not reset.
          await runtime.update('child', true, api2);
          expect(runtime.session, same(newSession));
          expect(newSession.isInvalidated, isFalse);
        } finally {
          if (!api1.operationRelease!.isCompleted) {
            api1.operationRelease!.complete();
          }
        }
      },
    );
  });

  group('A1: send admission is rechecked after identity', () {
    final scope = jsonEncode(['child', 'f', 'e']);

    // Queues one message, holds simulated identity for the send POST and
    // applies [whileHeld] before releasing it.
    Future<FamilyChatTestApi> heldSend(
      Future<void> Function(FamilyChatDatabase db, FamilyChatSession session)
      whileHeld, {
      FamilyChatDatabase? database,
    }) async {
      final db = database ?? FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        expectedScope: scope,
        isCurrentAccount: () => true,
      );
      addTearDown(session.dispose);
      await session.start();
      expect(session.scope, scope);
      expect(session.serverVerified, isTrue);

      api
        ..heldOperation = 'sendFamilyChatMessage'
        ..operationEntered = Completer<void>()
        ..operationRelease = Completer<void>();
      try {
        await session.send('mom', 'Hello mom');
        final sync = session.synchronize().catchError((Object _) {});
        await api.operationEntered!.future.timeout(const Duration(seconds: 5));
        await whileHeld(db, session);
        if (!api.operationRelease!.isCompleted) {
          api.operationRelease!.complete();
        }
        await sync;
      } finally {
        if (!api.operationRelease!.isCompleted) {
          api.operationRelease!.complete();
        }
      }
      return api;
    }

    test('unchanged admission still sends (control)', () async {
      final api = await heldSend((_, _) async {});
      expect(api.dispatchedOperations, contains('sendFamilyChatMessage'));
      expect(api.rejectedOperations, isNot(contains('sendFamilyChatMessage')));
    });

    test('local OFF while identity is held sends nothing', () async {
      final api = await heldSend((db, _) async {
        await db.fence.revokeAccount('child');
      });
      expect(
        api.dispatchedOperations,
        isNot(contains('sendFamilyChatMessage')),
      );
      expect(api.rejectedOperations, contains('sendFamilyChatMessage'));
      expect(api.sendRequests, 0);
    });

    test('OFF then ON with a new stamp before release sends nothing', () async {
      final api = await heldSend((db, _) async {
        final token = await db.fence.revokeAccount('child');
        await db.fence.clearAccountRevocation('child', token);
        final version = (await db.fence.read())['version'] as String;
        expect(await db.fence.activate(version, 'child', scope, 'other'), true);
      });
      expect(
        api.dispatchedOperations,
        isNot(contains('sendFamilyChatMessage')),
      );
      expect(api.rejectedOperations, contains('sendFamilyChatMessage'));
    });

    test(
      'durable history clear on another connection blocks the old gesture',
      () async {
        final api = await heldSend((db, session) async {
          // Session memory still holds the old generation.
          await db.observeHistoryGeneration(scope, 1);
          expect(await db.historyAllows(scope, 0), false);
          expect(session.scope, scope);
        });
        expect(
          api.dispatchedOperations,
          isNot(contains('sendFamilyChatMessage')),
        );
        expect(api.rejectedOperations, contains('sendFamilyChatMessage'));
      },
    );

    test(
      'invalidation during the final history read is caught by the last recheck',
      () async {
        final db = _GatedHistoryDb();
        final historyRelease = Completer<void>();
        Future<void>? invalidation;
        try {
          final api = await heldSend((_, session) async {
            final historyEntered = Completer<void>();
            db
              ..historyEntered = historyEntered
              ..historyRelease = historyRelease;
            final api = session.api as FamilyChatTestApi;
            api.operationRelease!.complete();
            await historyEntered.future.timeout(const Duration(seconds: 5));
            invalidation = session.invalidate(preserveHistory: true);
            historyRelease.complete();
          }, database: db);
          await invalidation;
          expect(
            api.dispatchedOperations,
            isNot(contains('sendFamilyChatMessage')),
          );
          expect(api.rejectedOperations, contains('sendFamilyChatMessage'));
        } finally {
          if (!historyRelease.isCompleted) historyRelease.complete();
          db.historyRelease = null;
        }
      },
    );

    test(
      'same-UID OFF->ON by another actor during the held guarded history read sends nothing',
      () async {
        final db = _GatedHistoryDb();
        final historyRelease = Completer<void>();
        try {
          final api = await heldSend((db, session) async {
            final historyEntered = Completer<void>();
            (db as _GatedHistoryDb)
              ..historyEntered = historyEntered
              ..historyRelease = historyRelease;
            (session.api as FamilyChatTestApi).operationRelease!.complete();
            // Now held INSIDE withChatGuard's writer transaction.
            await historyEntered.future.timeout(const Duration(seconds: 5));
            // Another actor latches OFF and re-admits the same UID with a new
            // stamp via the independent fence (no writer lock, no deadlock).
            // Session memory (generation/stamp) is untouched.
            final token = await db.fence.revokeAccount('child');
            expect(await db.fence.clearAccountRevocation('child', token), true);
            final version = (await db.fence.read())['version'] as String;
            expect(
              await db.fence.activate(version, 'child', scope, 'other-actor'),
              true,
            );
            expect(session.isInvalidated, isFalse);
            historyRelease.complete();
          }, database: db);
          expect(
            api.dispatchedOperations,
            isNot(contains('sendFamilyChatMessage')),
          );
          expect(api.rejectedOperations, contains('sendFamilyChatMessage'));
        } finally {
          if (!historyRelease.isCompleted) historyRelease.complete();
          db.historyRelease = null;
        }
      },
    );
  });

  group('A1: in-flight boundary exemptions', () {
    test(
      'completeFamilyChatTreatment via recovery path remains exempt and succeeds after OFF',
      () async {
        final calls = <String>[];
        final client = MockClient((request) async {
          calls.add(request.url.path);
          return http.Response(
            jsonEncode({
              'result': {'acknowledged': true},
            }),
            200,
          );
        });
        addTearDown(client.close);

        final transport = AuthenticatedCallableTransport(
          client: client,
          projectId: 'test-project',
          identity: () async =>
              const CallableIdentity('child', 'token', 'app-check'),
          currentUid: () => 'child',
        );

        final medical = DatabaseImpl(NativeDatabase.memory());
        addTearDown(medical.close);
        final journal = FamilyTreatmentJournal(medical);

        final chatDb = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(chatDb.close);

        final operation = await journal.prepare(
          uid: 'child',
          familyId: 'fam',
          messageId: 'msg-clinical-1',
          installationId: 'inst-1',
          proof: 'proof-123',
        );
        await medical.customStatement(
          'UPDATE family_treatment_journal SET meal_id=42,applied_at=1000 WHERE claim_id=?',
          [operation.claimId],
        );

        await chatDb.fence.revokeAccount('child');
        expect(await chatDb.fence.accountRevocation('child'), isNotNull);

        await recoverFamilyTreatmentAcknowledgements(
          journal: journal,
          api: FamilyChatRemote(transport, 'child'),
          currentUid: () => 'child',
        );

        expect(calls, ['/completeFamilyChatTreatment']);
        expect(
          (await journal.get(operation.claimId, 'child'))!.acknowledged,
          true,
        );
        expect(await journal.pendingAcknowledgements('child'), isEmpty);
      },
    );
  });
}
