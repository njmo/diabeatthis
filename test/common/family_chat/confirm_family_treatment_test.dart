import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_chat/application/confirm_family_treatment.dart';
import 'package:diabeatthis/common/family_chat/application/family_treatment_consumption_recovery.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_remote.dart';
import 'package:diabeatthis/common/family_chat/domain/family_treatment_authorization.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/family_treatment_journal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Api implements FamilyChatApi {
  _Api(this.journal);
  final FamilyTreatmentJournal journal;
  FamilyTreatmentOperation? operation;
  bool offline = false, failAck = false, completed = false;
  bool enabled = true;
  String role = 'child';
  int lease = 60000;
  int accountOffGeneration = 0, familyOffGeneration = 0;
  double? returnedQuantity;
  Future<void> Function()? afterClaim;
  Future<void> Function()? beforeConfig;
  Future<void> Function()? afterComplete;
  final calls = <String>[];
  final failingClaims = <String>{};
  bool allowMultipleIntents = false;
  final unavailableMessages = <String>{};
  String? unavailableReason;
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) async {
    if (allowRequest != null && !await allowRequest()) {
      throw const CallableFailure('cancelled');
    }
    calls.add(name);
    if (name == 'getFamilyChatConfig') {
      await beforeConfig?.call();
      // Proof is present before the first potentially networking operation.
      final rows = await journal.db
          .customSelect('SELECT claim_id FROM family_treatment_journal')
          .get();
      expect(rows, allowMultipleIntents ? isNotEmpty : hasLength(1));
      if (offline) throw const CallableFailure('unavailable');
      if (rows.length == 1) {
        operation = await journal.get(
          rows.single.read<String>('claim_id'),
          'child',
        );
      }
      return {
        'uid': 'child',
        'familyId': 'family',
        'epoch': 'epoch',
        'account': {'enabled': enabled, 'offGeneration': accountOffGeneration},
        'policy': {'enabled': true, 'offGeneration': familyOffGeneration},
        'members': [
          {'uid': 'child', 'role': role},
        ],
      };
    }
    if (name == 'claimFamilyChatTreatment') {
      operation = await journal.find(
        'child',
        'family',
        data['messageId'] as String,
      );
      if (unavailableMessages.contains(data['messageId'])) {
        throw CallableFailure(
          'rejected',
          rejectionCode: 'not-found',
          rejectionReason: unavailableReason,
        );
      }
      expect(data['proof'], operation!.proof);
      expect(data['quantity'], operation!.actualQuantity);
      expect(
        data['authorization'],
        familyTreatmentAuthorizationJson(operation!.authorization!),
      );
      final quantity = returnedQuantity ?? data['quantity'] as double? ?? 2;
      await afterClaim?.call();
      return {
        'claimId': operation!.claimId,
        if (completed) 'completed': true,
        'serverTime': 1000,
        'executionUntil': 1000 + lease,
        'treatment': {
          'foodName': 'Frozen product',
          'quantity': quantity,
          'grams': quantity * 5,
          'carbs': quantity * 4,
        },
      };
    }
    if (name == 'completeFamilyChatTreatment') {
      if (failAck || failingClaims.contains(data['claimId'])) {
        throw const CallableFailure('unavailable');
      }
      expect(
        (await journal.get(data['claimId'] as String, 'child'))!.mealId,
        isNotNull,
      );
      await afterComplete?.call();
      return {'ok': true};
    }
    throw StateError(name);
  }
}

void main() {
  late DatabaseImpl medical;
  late FamilyChatDatabase chat;
  late FamilyTreatmentJournal journal;
  late _Api api;
  late ConfirmFamilyTreatment executor;
  String? uid;
  late bool patient;
  late int saves;
  Future<void> Function()? beforeClinical;
  FamilyTreatmentAuthorization? observedAuthorization;
  Future<void> cacheParent(String id, {int generation = 0}) => chat
      .saveMessage(jsonEncode(['child', 'family', 'epoch']), 'mom', {
        'id': id,
        'kind': 'lowTreatment',
        'senderUid': 'mom',
        'historyGeneration': generation,
        'sentAt': 1000,
        'sequence': 1,
      })
      .then((_) {});
  setUp(() async {
    medical = DatabaseImpl(NativeDatabase.memory());
    chat = FamilyChatDatabase(NativeDatabase.memory());
    journal = FamilyTreatmentJournal(medical);
    api = _Api(journal);
    uid = 'child';
    patient = true;
    saves = 0;
    beforeClinical = null;
    observedAuthorization = (
      epoch: 'epoch',
      accountOffGeneration: 0,
      familyOffGeneration: 0,
    );
    await chat.activateChat(
      'child',
      jsonEncode(['child', 'family', 'epoch']),
      'stamp',
    );
    await cacheParent('message');
    executor = ConfirmFamilyTreatment(
      chatDb: chat,
      journal: journal,
      api: api,
      currentUid: () => uid,
      observedAuthorization: () => observedAuthorization,
      clinicalAuthorized: (_) async {
        await beforeClinical?.call();
        return patient;
      },
      save: (snapshot, confirmedAt) async {
        expect(snapshot['foodName'], 'Frozen product');
        expect(snapshot['carbs'], (snapshot['quantity'] as num) * 4);
        saves++;
        await medical.customStatement(
          "INSERT INTO meal(name,planned_at,status,purpose) VALUES('record',1000,'confirmed','lowTreatment')",
        );
        return (await medical
                .customSelect('SELECT last_insert_rowid() AS id')
                .getSingle())
            .read<int>('id');
      },
    );
  });
  tearDown(() async {
    await chat.close();
    await medical.close();
  });

  test(
    'an explicit confirmation saves once, duplicate callbacks reuse the journal',
    () async {
      final first = await executor.confirm('message');
      final second = await executor.confirm('message');
      expect(first, second);
      expect(first.acknowledged, true);
      expect(saves, 1);
      expect(
        api.calls.where((name) => name == 'claimFamilyChatTreatment'),
        hasLength(1),
      );
      expect(await medical.select(medical.meal).get(), hasLength(1));
    },
  );
  for (final recovery in [false, true]) {
    for (final transition in [
      'off',
      'off-on',
      'account',
      'history-clear',
      'history-clear-during-authorization',
      'off-on-during-authorization',
    ]) {
      test(
        'claim after held identity respects $transition (recovery=$recovery)',
        () async {
          if (recovery) {
            api.offline = true;
            await expectLater(
              executor.confirm('message'),
              throwsA(isA<CallableFailure>()),
            );
            api.offline = false;
          }
          final entered = Completer<void>();
          final release = Completer<void>();
          final authorized = Completer<void>();
          final releaseAuthorization = Completer<void>();
          var holdClaim = false;
          final requests = <String>[];
          final client = MockClient((request) async {
            final operation = request.url.pathSegments.last;
            requests.add(operation);
            final data = Map<String, Object?>.from(
              (jsonDecode(request.body) as Map)['data'] as Map,
            );
            final result = await api.call(operation, data);
            if (operation == 'getFamilyChatConfig') holdClaim = true;
            return http.Response(jsonEncode({'result': result}), 200);
          });
          addTearDown(client.close);
          final remote = FamilyChatRemote(
            AuthenticatedCallableTransport(
              client: client,
              projectId: 'test-project',
              identity: () async {
                if (holdClaim) {
                  entered.complete();
                  await release.future;
                }
                return const CallableIdentity('child', 'token', 'app-check');
              },
              currentUid: () => uid,
            ),
            'child',
          );
          final guarded = ConfirmFamilyTreatment(
            chatDb: chat,
            journal: journal,
            api: remote,
            currentUid: () => uid,
            clinicalAuthorized: executor.clinicalAuthorized,
            observedAuthorization: () => observedAuthorization,
            save: executor.save,
          );
          final pending = guarded.confirm('message', recovery: recovery);
          final failure = expectLater(pending, throwsA(isA<CallableFailure>()));
          try {
            await entered.future;
            expect(requests, ['getFamilyChatConfig']);
            final scope = jsonEncode(['child', 'family', 'epoch']);
            if (transition.endsWith('-during-authorization')) {
              beforeClinical = () async {
                authorized.complete();
                await releaseAuthorization.future;
              };
              release.complete();
              await authorized.future;
            }
            switch (transition) {
              case 'off':
                await chat.fence.revokeAccount('child');
              case 'off-on':
              case 'off-on-during-authorization':
                final token = await chat.fence.revokeAccount('child');
                await chat.deactivateChat();
                expect(
                  await chat.fence.clearAccountRevocation('child', token),
                  true,
                );
                await chat.activateChat('child', scope, 'new-stamp');
              case 'account':
                uid = 'other';
              case 'history-clear':
              case 'history-clear-during-authorization':
                await chat.beginHistoryClear(scope, 0, 'clear');
            }
          } finally {
            if (!release.isCompleted) release.complete();
            releaseAuthorization.complete();
          }
          await failure;
          expect(
            requests.where((name) => name == 'claimFamilyChatTreatment'),
            isEmpty,
          );
          expect(saves, 0);
          expect(await medical.select(medical.meal).get(), isEmpty);
        },
      );
    }
  }
  test(
    'an old button without its cached source cannot create a new claim',
    () async {
      await chat.customStatement('DELETE FROM chat_messages');
      await expectLater(executor.confirm('message'), throwsStateError);
      expect(api.calls, isEmpty);
      expect(saves, 0);
    },
  );
  test(
    'clearing history after an issued lease does not lose its clinical ACK',
    () async {
      api.afterClaim = () async {
        await chat.beginHistoryClear(
          jsonEncode(['child', 'family', 'epoch']),
          0,
          'clear',
        );
      };
      final result = await executor.confirm('message');
      expect(result.acknowledged, true);
      expect(saves, 1);
      expect(api.calls, [
        'getFamilyChatConfig',
        'claimFamilyChatTreatment',
        'completeFamilyChatTreatment',
      ]);
    },
  );
  test(
    'one automatic worker stops before the clinical save when OFF completes during a held claim',
    () async {
      api.offline = true;
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      api.offline = false;
      final entered = Completer<void>(), release = Completer<void>();
      api.afterClaim = () async {
        entered.complete();
        await release.future;
      };
      var admitted = true;
      final worker = FamilyTreatmentConsumptionWorker(
        ready: () => admitted,
        recover: () => recoverFamilyTreatmentConsumptions(
          executor: executor,
          admitted: () => admitted,
        ),
      );
      addTearDown(worker.dispose);
      final pending = worker.pump();
      await entered.future;
      for (var index = 0; index < 100; index++) {
        unawaited(worker.pump());
      }
      admitted = false;
      await chat.fence.revokeAccount('child');
      await journal.cancelUnapplied('child');
      release.complete();
      await pending;
      expect(saves, 0);
      expect(
        api.calls.where((value) => value == 'claimFamilyChatTreatment'),
        hasLength(1),
      );
      expect(
        (await journal.find('child', 'family', 'message'))!.cancelled,
        true,
      );
    },
  );

  test(
    'UID change during automatic config fetch cannot advance to claim or save',
    () async {
      api.offline = true;
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      api.offline = false;
      final entered = Completer<void>(), release = Completer<void>();
      api.beforeConfig = () async {
        entered.complete();
        await release.future;
      };
      final pending = recoverFamilyTreatmentConsumptions(
        executor: executor,
        admitted: () => uid == 'child',
      );
      await entered.future;
      uid = 'other';
      release.complete();
      await pending;
      expect(saves, 0);
      expect(
        api.calls.where((value) => value == 'claimFamilyChatTreatment'),
        isEmpty,
      );
    },
  );

  test(
    'manual and automatic retries share the existing medical transaction and save only once',
    () async {
      api.offline = true;
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      api.offline = false;
      await Future.wait([
        executor.confirm('message'),
        recoverFamilyTreatmentConsumptions(
          executor: executor,
          admitted: () => true,
        ),
      ]);
      expect(saves, 1);
      expect(await medical.select(medical.meal).get(), hasLength(1));
    },
  );

  test(
    'background during a held automatic claim prevents save without revoking consent and resume retries once',
    () async {
      api.offline = true;
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      api.offline = false;
      final entered = Completer<void>(), release = Completer<void>();
      api.afterClaim = () async {
        entered.complete();
        await release.future;
      };
      var foreground = true, elapsed = 0;
      final worker = FamilyTreatmentConsumptionWorker(
        ready: () => foreground,
        elapsedMilliseconds: () => elapsed,
        recover: () => recoverFamilyTreatmentConsumptions(
          executor: executor,
          admitted: () => foreground,
        ),
      );
      addTearDown(worker.dispose);
      final pending = worker.pump();
      await entered.future;
      foreground = false;
      release.complete();
      await pending;
      expect(
        (await chat.activeChat())['enabled'],
        true,
      ); // No OFF/fence transition.
      expect(saves, 0);
      expect(
        (await journal.find('child', 'family', 'message'))!.cancelled,
        false,
      );
      foreground = true;
      elapsed = 30000;
      api.afterClaim = null;
      await worker.pump();
      expect(saves, 1);
    },
  );

  test(
    'automatic foreground loss inside the clinical writer rolls back its tentative meal',
    () async {
      api.offline = true;
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      api.offline = false;
      var foreground = true;
      final original = executor;
      executor = ConfirmFamilyTreatment(
        chatDb: chat,
        journal: journal,
        api: api,
        currentUid: () => uid,
        clinicalAuthorized: original.clinicalAuthorized,
        save: (snapshot, confirmedAt) async {
          final meal = await original.save(snapshot, confirmedAt);
          foreground = false;
          return meal;
        },
      );
      await recoverFamilyTreatmentConsumptions(
        executor: executor,
        admitted: () => foreground,
      );
      expect(await medical.select(medical.meal).get(), isEmpty);
      expect(
        (await journal.find('child', 'family', 'message'))!.mealId,
        isNull,
      );
    },
  );

  for (final reason in [
    'consumption-request-expired',
    'consumption-request-unavailable',
  ]) {
    test(
      'automatic recovery cancels a definitively unavailable source: $reason',
      () async {
        api.offline = true;
        await expectLater(
          executor.confirm('message'),
          throwsA(isA<CallableFailure>()),
        );
        api.offline = false;
        api.unavailableReason = reason;
        api.unavailableMessages.add('message');
        await recoverFamilyTreatmentConsumptions(
          executor: executor,
          admitted: () => true,
        );
        expect(saves, 0);
        expect(
          (await journal.find('child', 'family', 'message'))!.cancelled,
          true,
        );
        final calls = api.calls.length;
        await recoverFamilyTreatmentConsumptions(
          executor: executor,
          admitted: () => true,
        );
        expect(api.calls.length, calls);
      },
    );
  }

  test('recovery cannot invent or authorize a missing intent', () async {
    observedAuthorization = (
      epoch: 'epoch',
      accountOffGeneration: 0,
      familyOffGeneration: 0,
    );
    await expectLater(
      executor.confirm('missing', recovery: true),
      throwsA(isA<CallableFailure>()),
    );
    expect(api.calls, isEmpty);
    expect(await journal.find('child', 'family', 'missing'), isNull);
    expect(saves, 0);
  });

  test(
    'automatic recovery replays a durable explicit offline quantity once without new UI consent',
    () async {
      api.offline = true;
      await expectLater(
        executor.confirm('message', actualQuantity: 1.5),
        throwsA(isA<CallableFailure>()),
      );
      final before = await journal.find('child', 'family', 'message');
      expect(before!.mealId, isNull);
      api.offline = false;
      observedAuthorization =
          null; // A restarted executor has no displayed UI action.
      await recoverFamilyTreatmentConsumptions(
        executor: executor,
        admitted: () => true,
      );
      await recoverFamilyTreatmentConsumptions(
        executor: executor,
        admitted: () => true,
      );
      final after = await journal.find('child', 'family', 'message');
      expect(saves, 1);
      expect(after!.mealId, isNotNull);
      expect(after.proof, before.proof);
      expect(after.confirmedAt, before.confirmedAt);
      expect(after.actualQuantity, 1.5);
    },
  );

  test(
    'automatic recovery never creates an intent just from entering the chat',
    () async {
      await recoverFamilyTreatmentConsumptions(
        executor: executor,
        admitted: () => true,
      );
      expect(api.calls, isEmpty);
      expect(saves, 0);
      expect(await journal.find('child', 'family', 'message'), isNull);
    },
  );

  test(
    'automatic replay after closing and reopening the clinical SQLite database preserves proof and amount',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'family-consumption-restart-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/clinical.sqlite');
      final save = executor.save;
      final clinicalAuthorized = executor.clinicalAuthorized;
      Future<void> reopen() async {
        await medical.close();
        medical = DatabaseImpl(NativeDatabase(file));
        journal = FamilyTreatmentJournal(medical);
        api = _Api(journal);
        executor = ConfirmFamilyTreatment(
          chatDb: chat,
          journal: journal,
          api: api,
          currentUid: () => uid,
          clinicalAuthorized: clinicalAuthorized,
          save: save,
        );
      }

      await reopen();
      api.offline = true;
      await expectLater(
        executor.confirm(
          'message',
          actualQuantity: 1.5,
          acceptedAuthorization: observedAuthorization,
        ),
        throwsA(isA<CallableFailure>()),
      );
      final before = await journal.find('child', 'family', 'message');
      await reopen();
      await recoverFamilyTreatmentConsumptions(
        executor: executor,
        admitted: () => true,
      );
      final after = await journal.find('child', 'family', 'message');
      expect(after!.proof, before!.proof);
      expect(after.actualQuantity, 1.5);
      expect(after.confirmedAt, before.confirmedAt);
      expect(after.mealId, isNotNull);
      expect(saves, 1);
    },
  );

  test(
    'temporary sender OFF represented by not-found keeps the exact intention retryable',
    () async {
      api.offline = true;
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      api.offline = false;
      api.unavailableMessages.add('message');
      await recoverFamilyTreatmentConsumptions(
        executor: executor,
        admitted: () => true,
      );
      expect(saves, 0);
      expect(
        (await journal.find('child', 'family', 'message'))!.cancelled,
        false,
      );
      api.unavailableMessages.clear();
      await recoverFamilyTreatmentConsumptions(
        executor: executor,
        admitted: () => true,
      );
      expect(saves, 1);
    },
  );

  test(
    'persisted fair order reaches a newer consent behind twenty inaccessible requests',
    () async {
      api.allowMultipleIntents = true;
      final installation = await chat.fence.nextRegistration();
      for (var index = 0; index < 21; index++) {
        final id = 'message$index';
        await cacheParent(id);
        await journal.prepare(
          uid: 'child',
          familyId: 'family',
          messageId: id,
          installationId: installation['installationId'] as String,
          proof: 'proof-$index',
          confirmedAt: 1000 + index,
          authorization: observedAuthorization,
        );
        if (index < 20) api.unavailableMessages.add(id);
      }
      for (var index = 0; index < 4; index++) {
        await recoverFamilyTreatmentConsumptions(
          executor: executor,
          admitted: () => true,
        );
        expect(saves, 0);
      }
      await recoverFamilyTreatmentConsumptions(
        executor: executor,
        admitted: () => true,
      );
      expect(saves, 1);
      expect(
        (await journal.find('child', 'family', 'message20'))!.mealId,
        isNotNull,
      );
    },
  );

  test(
    'OFF to ON invalidates pending automatic consumption while committed ACK remains separate',
    () async {
      api.offline = true;
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      api.offline = false;
      api.accountOffGeneration++;
      await recoverFamilyTreatmentConsumptions(
        executor: executor,
        admitted: () => true,
      );
      expect(saves, 0);
      expect(
        (await journal.find('child', 'family', 'message'))!.cancelled,
        true,
      );
    },
  );

  test(
    'automatic recovery captures guard stamp and refuses a replacement scope during patient verification',
    () async {
      api.offline = true;
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      api.offline = false;
      beforeClinical = () async {
        beforeClinical = null;
        await chat.activateChat(
          'child',
          jsonEncode(['child', 'new-family', 'new-epoch']),
          'new-stamp',
        );
      };
      final calls = api.calls.length;
      await recoverFamilyTreatmentConsumptions(
        executor: executor,
        admitted: () => true,
      );
      expect(api.calls.length, calls);
      expect(saves, 0);
    },
  );
  test(
    'legacy unversioned intent remains blocked without rewriting consent',
    () async {
      final installation = await chat.fence.nextRegistration();
      await journal.prepare(
        uid: 'child',
        familyId: 'family',
        messageId: 'message',
        installationId: installation['installationId'] as String,
        proof: 'proof',
      );
      observedAuthorization = (
        epoch: 'epoch',
        accountOffGeneration: 0,
        familyOffGeneration: 0,
      );
      await expectLater(
        executor.confirm('message', recovery: true),
        throwsA(isA<CallableFailure>()),
      );
      expect(api.calls, isEmpty);
      expect(
        (await journal.find('child', 'family', 'message'))!.authorization,
        isNull,
      );
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      expect(api.calls, isEmpty);
      expect(saves, 0);
    },
  );
  test(
    'a tap before an in-flight OFF→ON cannot bind the newer consent',
    () async {
      final entered = Completer<void>(), gate = Completer<void>();
      api.beforeConfig = () {
        entered.complete();
        return gate.future;
      };
      final confirmation = executor.confirm('message');
      await entered.future;
      api.accountOffGeneration = 1;
      gate.complete();
      await expectLater(confirmation, throwsA(isA<CallableFailure>()));
      expect(
        (await journal.find(
          'child',
          'family',
          'message',
        ))!.authorization!.accountOffGeneration,
        0,
      );
      expect(
        api.calls.where((name) => name == 'claimFamilyChatTreatment'),
        isEmpty,
      );
      expect(saves, 0);
    },
  );
  test(
    'missing displayed authorization cannot create a new clinical intent',
    () async {
      observedAuthorization = null;
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      expect(await journal.find('child', 'family', 'message'), isNull);
      expect(api.calls, isEmpty);
      expect(saves, 0);
    },
  );
  test(
    'displayed consent is captured before medical authorization awaits',
    () async {
      final entered = Completer<void>(), gate = Completer<void>();
      beforeClinical = () {
        if (!entered.isCompleted) entered.complete();
        return gate.future;
      };
      final confirmation = executor.confirm('message');
      await entered.future;
      observedAuthorization = (
        epoch: 'epoch',
        accountOffGeneration: 1,
        familyOffGeneration: 0,
      );
      api.accountOffGeneration = 1;
      gate.complete();
      await expectLater(confirmation, throwsA(isA<CallableFailure>()));
      expect(
        (await journal.find(
          'child',
          'family',
          'message',
        ))!.authorization!.accountOffGeneration,
        0,
      );
      expect(
        api.calls.where((name) => name == 'claimFamilyChatTreatment'),
        isEmpty,
      );
      expect(saves, 0);
    },
  );
  for (final partial in [
    'authorization_epoch',
    'account_off_generation',
    'family_off_generation',
  ]) {
    test('partially populated consent is never replaced: $partial', () async {
      final installation = await chat.fence.nextRegistration();
      await journal.prepare(
        uid: 'child',
        familyId: 'family',
        messageId: 'message',
        installationId: installation['installationId'] as String,
        proof: 'proof',
      );
      final value = partial == 'authorization_epoch' ? 'old' : 7;
      await medical.customStatement(
        'UPDATE family_treatment_journal SET $partial=?',
        [value],
      );
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      final row = await medical
          .customSelect('SELECT $partial FROM family_treatment_journal')
          .getSingle();
      expect(row.data[partial], value);
      expect(api.calls, isEmpty);
      expect(saves, 0);
    });
  }
  for (final revoke in ['account', 'family', 'unchanged']) {
    test(
      'observed consent is durable before HTTP and immutable during recovery: $revoke',
      () async {
        observedAuthorization = (
          epoch: 'epoch',
          accountOffGeneration: 0,
          familyOffGeneration: 0,
        );
        api.offline = true;
        await expectLater(
          executor.confirm('message'),
          throwsA(isA<CallableFailure>()),
        );
        final operation = await journal.find('child', 'family', 'message');
        expect(operation!.authorization, observedAuthorization);
        api.offline = false;
        if (revoke == 'account') api.accountOffGeneration = 1;
        if (revoke == 'family') api.familyOffGeneration = 1;
        observedAuthorization = (
          epoch: 'epoch',
          accountOffGeneration: api.accountOffGeneration,
          familyOffGeneration: api.familyOffGeneration,
        );
        if (revoke == 'unchanged') {
          await executor.confirm('message', recovery: true);
          expect(saves, 1);
        } else {
          await expectLater(
            executor.confirm('message', recovery: true),
            throwsA(isA<CallableFailure>()),
          );
          expect(
            api.calls.where((name) => name == 'claimFamilyChatTreatment'),
            isEmpty,
          );
          expect(saves, 0);
        }
        expect(
          (await journal.find('child', 'family', 'message'))!.authorization,
          operation.authorization,
        );
      },
    );
  }
  test(
    'offline intent is durable, produces no clinical effect and uses the same proof after retry',
    () async {
      api.offline = true;
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      expect(saves, 0);
      final rows = await medical
          .customSelect('SELECT proof FROM family_treatment_journal')
          .get();
      final proof = rows.single.read<String>('proof');
      api.offline = false;
      await executor.confirm('message');
      expect(api.operation!.proof, proof);
      expect(saves, 1);
    },
  );
  test(
    'lost ACK retries only finalization even after the chat guard is disabled',
    () async {
      api.failAck = true;
      final result = await executor.confirm('message');
      expect(result.mealId, isNotNull);
      expect(result.acknowledged, false);
      await chat.deactivateChat();
      await journal.cancelUnapplied('child');
      expect(
        (await journal.find('child', 'family', 'message'))!.cancelled,
        false,
      );
      api.failAck = false;
      api.calls.clear();
      expect(await executor.finish(api.operation!), true);
      expect(api.calls, ['completeFamilyChatTreatment']);
      expect(saves, 1);
      expect(
        (await journal.get(api.operation!.claimId, 'child'))!.acknowledged,
        true,
      );
    },
  );
  test(
    'local OFF cancels only unapplied intents and cannot be undone by ON',
    () async {
      api.offline = true;
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      await journal.cancelUnapplied('other');
      expect(
        (await journal.find('child', 'family', 'message'))!.cancelled,
        false,
      );
      await journal.cancelUnapplied('child');
      api.offline = false;
      api.calls.clear();
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      await expectLater(
        executor.confirm('message', recovery: true),
        throwsA(isA<CallableFailure>()),
      );
      expect(api.calls, isEmpty);
      expect(saves, 0);
    },
  );
  test(
    'cancellation after claim but before clinical transaction prevents the effect',
    () async {
      api.afterClaim = () => journal.cancelUnapplied('child');
      await expectLater(executor.confirm('message'), throwsStateError);
      expect(saves, 0);
      expect(await medical.select(medical.meal).get(), isEmpty);
    },
  );
  test(
    'actual quantity requires an explicit matching retry after offline preparation',
    () async {
      api.offline = true;
      await expectLater(
        executor.confirm('message', actualQuantity: 1.5),
        throwsA(isA<CallableFailure>()),
      );
      final operation = await journal.find('child', 'family', 'message');
      expect(operation!.actualQuantity, 1.5);
      api.offline = false;
      await expectLater(
        executor.confirm('message'),
        throwsA(isA<CallableFailure>()),
      );
      expect(saves, 0);
      await executor.confirm('message', actualQuantity: 1.5);
      expect(api.operation!.proof, operation.proof);
      expect(api.operation!.actualQuantity, 1.5);
      expect(saves, 1);
      await expectLater(
        executor.confirm('message', actualQuantity: 2),
        throwsStateError,
      );
      expect(saves, 1);
    },
  );
  test('a claim cannot change the persisted consumed quantity', () async {
    api.returnedQuantity = 2;
    await expectLater(
      executor.confirm('message', actualQuantity: 1),
      throwsStateError,
    );
    expect(saves, 0);
  });
  for (final amount in [0.0, -1.0, double.nan, double.infinity, 10001.0]) {
    test('invalid consumed quantity cannot prepare or send: $amount', () async {
      await expectLater(
        executor.confirm('message', actualQuantity: amount),
        throwsArgumentError,
      );
      expect(api.calls, isEmpty);
      expect(await journal.find('child', 'family', 'message'), isNull);
      expect(saves, 0);
    });
  }
  test(
    'a server-completed claim without a local result cannot create a replacement meal',
    () async {
      api.completed = true;
      expect((await executor.confirm('message')).mealId, isNull);
      await executor.confirm('message');
      expect(saves, 0);
      expect(
        api.calls.where((name) => name == 'claimFamilyChatTreatment'),
        hasLength(1),
      );
    },
  );
  test('recovery after OFF retries only committed clinical ACKs', () async {
    api.failAck = true;
    await executor.confirm('message');
    await journal.prepare(
      uid: 'child',
      familyId: 'family',
      messageId: 'unapplied',
      installationId: api.operation!.installationId,
      proof: 'different-proof',
    );
    await chat.deactivateChat();
    api.calls.clear();
    await recoverFamilyTreatmentAcknowledgements(
      journal: journal,
      api: api,
      currentUid: () => uid,
    );
    expect(api.calls, ['completeFamilyChatTreatment']);
    expect(await journal.pendingAcknowledgements('child'), hasLength(1));
    api.failAck = false;
    await recoverFamilyTreatmentAcknowledgements(
      journal: journal,
      api: api,
      currentUid: () => uid,
    );
    expect(await journal.pendingAcknowledgements('child'), isEmpty);
    expect(saves, 1);
    final pending = await journal.find('child', 'family', 'unapplied');
    expect(pending!.mealId, isNull);
    expect(pending.acknowledged, false);
  });
  test('recovery never sends another account clinical proofs', () async {
    api.failAck = true;
    await executor.confirm('message');
    api.calls.clear();
    uid = 'other';
    await recoverFamilyTreatmentAcknowledgements(
      journal: journal,
      api: api,
      currentUid: () => uid,
    );
    expect(api.calls, isEmpty);
    expect(await journal.pendingAcknowledgements('child'), hasLength(1));
    expect(saves, 1);
  });
  test('UID change during recovery leaves local ACK pending', () async {
    api.failAck = true;
    await executor.confirm('message');
    api.failAck = false;
    api.afterComplete = () async {
      uid = 'other';
    };
    await recoverFamilyTreatmentAcknowledgements(
      journal: journal,
      api: api,
      currentUid: () => uid,
    );
    expect(await journal.pendingAcknowledgements('child'), hasLength(1));
    expect(saves, 1);
  });
  test('permanent first-page failures cannot starve later ACKs', () async {
    FamilyTreatmentOperation? last;
    for (var i = 0; i < 21; i++) {
      final operation = await journal.prepare(
        uid: 'child',
        familyId: 'family',
        messageId: 'message_$i',
        installationId: 'installation',
        proof: 'proof_$i',
      );
      await medical.customStatement(
        'UPDATE family_treatment_journal SET meal_id=42,applied_at=? WHERE claim_id=?',
        [i, operation.claimId],
      );
      if (i < 20) api.failingClaims.add(operation.claimId);
      last = operation;
    }
    await recoverFamilyTreatmentAcknowledgements(
      journal: journal,
      api: api,
      currentUid: () => uid,
    );
    expect(api.calls, hasLength(20));
    expect((await journal.get(last!.claimId, 'child'))!.acknowledged, false);
    // A new service instance and disabled chat do not reset the durable order.
    await chat.deactivateChat();
    await recoverFamilyTreatmentAcknowledgements(
      journal: FamilyTreatmentJournal(medical),
      api: api,
      currentUid: () => uid,
    );
    expect((await journal.get(last.claimId, 'child'))!.acknowledged, true);
    expect(await journal.pendingAcknowledgements('child'), hasLength(20));
    expect(saves, 0);
  });
  for (final invalid in ['caregiver', 'off', 'uid', 'guard', 'lease']) {
    test(
      'invalid authorization cannot create a clinical record: $invalid',
      () async {
        if (invalid == 'caregiver') api.role = 'managingCaregiver';
        if (invalid == 'off') api.enabled = false;
        if (invalid == 'uid') {
          api.afterClaim = () async {
            uid = 'other';
          };
        }
        if (invalid == 'guard') {
          api.afterClaim = () async {
            await chat.deactivateChat();
          };
        }
        if (invalid == 'lease') api.lease = 0;
        await expectLater(executor.confirm('message'), throwsStateError);
        expect(saves, 0);
        expect(await medical.select(medical.meal).get(), isEmpty);
      },
    );
  }
  test('a caregiver device cannot even prepare a consumption intent', () async {
    patient = false;
    await expectLater(executor.confirm('message'), throwsStateError);
    expect(api.calls, isEmpty);
    expect(
      await medical
          .customSelect('SELECT * FROM family_treatment_journal')
          .get(),
      isEmpty,
    );
  });
}
