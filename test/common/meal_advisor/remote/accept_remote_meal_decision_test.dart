import 'dart:convert';

import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/meal_advisor/manual_meal_choice.dart';
import 'package:diabeatthis/common/meal_advisor/remote/accept_remote_meal_decision.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:diabeatthis/common/meal_advisor/remote/scheduled_meal_decision_journal.dart';
import 'package:diabeatthis/common/meal_advisor/remote/start_accepted_caregiver_meal.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/repositories/meal_advisor_result_store.dart';
import 'package:diabeatthis/features/dashboard/data/use_cases/meal_advisor_result_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../foreground/tasks/meal_monitor_test.dart' show testBolusWizard;

const source = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const requestId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const acceptanceToken = 'cccccccccccccccccccccccccccccccc';

MealDecisionRemoteRequest request({
  String owner = 'child',
  int revision = 1,
  String answer = 'insulinThenWait',
}) => MealDecisionRemoteRequest({
  'id': requestId,
  'mealId': '1',
  'ownerUid': owner,
  'sourceId': source,
  'mealRevision': revision,
  'status': 'answered',
  'deadline': DateTime.now()
      .add(const Duration(minutes: 4))
      .millisecondsSinceEpoch,
  'createdAt': DateTime.now().millisecondsSinceEpoch,
  'claimedByUid': null,
  'response': {
    'type': answer,
    'minutes': answer == 'insulinThenWait' ? 15 : null,
    'message': 'Wait',
    'targetSuggestion': null,
    'caregiverUid': 'caregiver',
    'caregiverName': 'Alex',
    'respondedAt': DateTime.now().millisecondsSinceEpoch,
  },
});

class ReceiptFixture {
  ReceiptFixture(this.db, this.container, this.calls);
  final DatabaseImpl db;
  final ProviderContainer container;
  final List<Map<String, dynamic>> calls;
  bool ackFails = true;
  late final MealAdvisorResultUseCase results = MealAdvisorResultUseCase(
    DriftMealAdvisorResultStore(dao: db.mealAdvisorResultDao),
  );
}

Future<ReceiptFixture> fixture({
  String uid = 'child',
  String localSource = source,
  ApplicationDeviceMode mode = ApplicationDeviceMode.patient,
}) async {
  final db = DatabaseImpl(NativeDatabase.memory());
  await db.customStatement(
    "UPDATE family_sync_identity SET owner_uid='child', source_id=? WHERE singleton=1",
    [localSource],
  );
  await db.customStatement(
    "INSERT INTO meal(id,name,planned_at,status,purpose) VALUES(1,'Lunch',1000,'planned','meal')",
  );
  await db.customStatement(
    "INSERT OR REPLACE INTO family_sync_outbox(kind,entity_id,revision,deleted) VALUES('meals','1',1,0)",
  );

  final calls = <Map<String, dynamic>>[];
  late ReceiptFixture result;
  final transport = AuthenticatedCallableTransport(
    client: MockClient((req) async {
      final data = Map<String, dynamic>.from(
        (jsonDecode(req.body) as Map)['data'] as Map,
      );
      calls.add(data);
      if (data['action'] == 'prepareAcceptance') {
        return http.Response(
          jsonEncode({
            'result': {
              'requestId': requestId,
              'acceptanceToken': acceptanceToken,
            },
          }),
          200,
        );
      }
      if (data['action'] == 'acknowledge' && result.ackFails) {
        throw StateError('offline');
      }
      return http.Response(
        jsonEncode({
          'result': data['action'] == 'fetch' ? {'requests': <Object>[]} : {},
        }),
        200,
      );
    }),
    projectId: 'test',
    identity: () async => CallableIdentity(uid, 'token', 'app-check'),
    currentUid: () => uid,
  );
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      googleAccountProvider.overrideWith(
        (_) => Stream.value(GoogleAccount(uid: uid)),
      ),
      applicationDeviceModeProvider.overrideWith((_) async => mode),
      authenticatedFamilyTransportProvider.overrideWithValue(transport),
    ],
  );
  result = ReceiptFixture(db, container, calls);

  container.listen(googleAccountProvider, (_, __) {});
  container.listen(applicationDeviceModeProvider, (_, __) {});
  await container.read(googleAccountProvider.future);

  await container.read(applicationDeviceModeProvider.future);

  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'parses the mirrored meal ID and response caregiver independently of the claim',
    () {
      final value = request();
      expect(value.mealId, 1);
      expect(value.claimedByUid, isNull);
      expect(value.respondingCaregiverUid, 'caregiver');
      expect(value.respondingCaregiverName, 'Alex');
      expect(value.advice?.caregiverId, 'caregiver');
      expect(value.advice?.caregiverRequestId, value.id);
    },
  );

  test(
    'a matching wizard activates a previously accepted caregiver plan once',
    () async {
      final f = await fixture();
      addTearDown(() async {
        f.container.dispose();
        await f.db.close();
      });
      await f.db.customStatement('UPDATE family_sync_identity SET enabled=1');
      await f.db.customStatement('UPDATE meal SET planned_at=? WHERE id=1', [
        DateTime.now().millisecondsSinceEpoch,
      ]);
      await f.db.customStatement(
        "INSERT INTO ingredient(id,name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,nutrition_confidence,is_reference) VALUES(1,'Lunch',17,0,0,0,1,1)",
      );
      await f.db.customStatement(
        'INSERT INTO meal_ingredients(meal_id,ingredient_id,amount,quantity_confidence) VALUES(1,1,1,1)',
      );
      final version = await f.db
          .customSelect(
            "SELECT revision FROM family_sync_outbox WHERE kind='meals' AND entity_id='1'",
          )
          .getSingle();
      await f.container.read(acceptRemoteMealDecisionProvider)(
        request(
          answer: 'insulinAndEat',
          revision: version.read<int>('revision'),
        ),
      );
      final start = f.container.read(startAcceptedMealFromCalculatorProvider);
      final at = DateTime.now();
      await start(testBolusWizard(createdAt: at, carbs: 20, insulin: 1.75));
      expect((await f.db.mealDao.getMealById(1))?.status, 'planned');
      final matching = testBolusWizard(createdAt: at, carbs: 17, insulin: 1.75);
      await start(matching);
      await start(matching);
      expect((await f.db.mealDao.getMealById(1))?.status, 'waiting-for-bolus');
      final waitingTransitions = await f.db
          .customSelect(
            "SELECT * FROM meal_status_history WHERE meal_id=1 AND status='waiting-for-bolus'",
          )
          .get();
      expect(waitingTransitions, hasLength(1));
    },
  );

  test(
    'offline acknowledgment leaves a durable receipt and a later replay completes it',
    () async {
      final f = await fixture();
      addTearDown(() async {
        f.container.dispose();
        await f.db.close();
      });

      final advice = await f.container.read(acceptRemoteMealDecisionProvider)(
        request(),
      );

      expect(advice?.source, 'caregiver');
      expect(advice?.caregiverId, 'caregiver');
      expect(advice?.caregiverRequestId, requestId);
      final saved = await f.results.loadMealAdvice(1);
      expect(saved?.source, 'caregiver');
      expect(saved?.caregiverId, 'caregiver');
      expect(saved?.caregiverRequestId, requestId);
      var receipt = await f.db
          .customSelect('SELECT * FROM family_meal_decision_receipts')
          .getSingle();
      expect(receipt.read<int>('acknowledged'), 0);
      expect(receipt.read<String>('acceptance_token'), acceptanceToken);
      expect(jsonDecode(receipt.read<String>('outcome_json')), {
        'source': 'caregiver',
        'decision': 'insulinThenWait',
        'minutes': 15,
        'caregiverUid': 'caregiver',
        'plannedAt': 1000,
      });
      f.ackFails = false;
      await f.container.read(reconcileMealDecisionReceiptsProvider)();
      receipt = await f.db
          .customSelect('SELECT * FROM family_meal_decision_receipts')
          .getSingle();
      expect(receipt.read<int>('acknowledged'), 1);
      final ack = f.calls.lastWhere((call) => call['action'] == 'acknowledge');
      expect(ack['acceptanceToken'], acceptanceToken);
      expect(ack['outcome']['caregiverUid'], 'caregiver');
    },
  );

  test(
    'final acceptance atomically starts the meal and stores its receipt',
    () async {
      final f = await fixture();
      addTearDown(() async {
        f.container.dispose();
        await f.db.close();
      });
      await f.container.read(acceptRemoteMealDecisionProvider)(
        request(),
        startMeal: true,
      );
      expect((await f.db.mealDao.getMealById(1))?.status, 'waiting-for-bolus');
      expect(
        (await f.results.loadMealAdvice(1))?.caregiverRequestId,
        requestId,
      );
      expect(
        (await f.db
                .customSelect('SELECT * FROM family_meal_decision_receipts')
                .getSingle())
            .read<int>('acknowledged'),
        0,
      );
    },
  );

  test(
    'scheduled prebolus acceptance keeps the meal planned and binds the receipt',
    () async {
      final f = await fixture();
      addTearDown(() async {
        f.container.dispose();
        await f.db.close();
      });
      final plannedAt = DateTime.now().add(const Duration(minutes: 20));
      await f.db.customStatement('UPDATE meal SET planned_at=? WHERE id=1', [
        plannedAt.millisecondsSinceEpoch,
      ]);
      await f.db.customStatement(
        "UPDATE family_sync_outbox SET revision=1 WHERE kind='meals' AND entity_id='1'",
      );
      await ScheduledMealDecisionJournal(
        f.db,
      ).remember(1, plannedAt, uid: 'child', requestId: requestId);

      await f.container.read(acceptRemoteMealDecisionProvider)(
        request(),
        startMeal: true,
      );

      expect((await f.db.mealDao.getMealById(1))?.status, 'planned');
      final receipt = await f.db
          .customSelect(
            'SELECT outcome_json FROM family_meal_decision_receipts',
          )
          .getSingle();
      expect(
        jsonDecode(receipt.read<String>('outcome_json')),
        containsPair('plannedAt', plannedAt.millisecondsSinceEpoch),
      );
      expect(
        jsonDecode(receipt.read<String>('outcome_json')),
        containsPair('scheduled', true),
      );
    },
  );

  for (final (answer, status) in [
    ('eatThenInsulin', 'eating-then-bolus'),
    ('insulinAndEat', 'waiting-for-bolus'),
  ]) {
    test('accepting $answer saves a separate, one-time start', () async {
      final f = await fixture();
      addTearDown(() async {
        f.container.dispose();
        await f.db.close();
      });
      await f.container.read(acceptRemoteMealDecisionProvider)(
        request(answer: answer),
      );
      expect((await f.db.mealDao.getMealById(1))?.status, 'planned');
      expect(await readAcceptedCaregiverMeal(f.db, 'someone-else', 1), isNull);
      expect(await readAcceptedCaregiverMeal(f.db, 'child', 1), isNotNull);
      final start = f.container.read(startAcceptedCaregiverMealProvider);
      expect(
        await Future.wait([start('child', 1), start('child', 1)]),
        unorderedEquals([true, false]),
      );
      expect((await f.db.mealDao.getMealById(1))?.status, status);
      expect(
        f.calls.where((call) => call['action'] == 'prepareAcceptance'),
        hasLength(1),
      );
    });
  }

  test('a moved meal does not reuse a previously accepted start', () async {
    final f = await fixture();
    addTearDown(() async {
      f.container.dispose();
      await f.db.close();
    });
    await f.container.read(acceptRemoteMealDecisionProvider)(
      request(answer: 'eatThenInsulin'),
    );
    await f.db.customStatement('UPDATE meal SET planned_at=2000 WHERE id=1');
    expect(await readAcceptedCaregiverMeal(f.db, 'child', 1), isNull);
    expect(
      await f.container.read(startAcceptedCaregiverMealProvider)('child', 1),
      isFalse,
    );
    expect((await f.db.mealDao.getMealById(1))?.status, 'planned');
  });

  test(
    'rejection preserves planned meal and records a manual choice',
    () async {
      SharedPreferences.setMockInitialValues({});
      final f = await fixture();
      addTearDown(() async {
        f.container.dispose();
        await f.db.close();
      });
      await f.container
          .read(acceptRemoteMealDecisionProvider)
          .reject(request());
      expect((await f.db.mealDao.getMealById(1))?.status, 'planned');
      expect(await f.results.loadMealAdvice(1), isNull);
      expect(
        await f.db
            .customSelect('SELECT * FROM family_meal_decision_receipts')
            .get(),
        isEmpty,
      );
      expect(
        f.calls.map((call) => call['action']),
        contains('abortAcceptance'),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(usesManualMealChoice(prefs, 1, 1000), isTrue);
      expect(usesManualMealChoice(prefs, 1, 2000), isFalse);
    },
  );

  test('an in-flight or recorded acceptance cannot be rejected', () async {
    final f = await fixture();
    addTearDown(() async {
      f.container.dispose();
      await f.db.close();
    });
    final decisions = f.container.read(acceptRemoteMealDecisionProvider);
    final acceptance = decisions(request());
    await expectLater(decisions.reject(request()), throwsStateError);
    await acceptance;
    await expectLater(decisions.reject(request()), throwsStateError);
    expect(
      f.calls.map((call) => call['action']),
      isNot(contains('abortAcceptance')),
    );
  });

  test('receipt failure rolls back starting the meal', () async {
    final f = await fixture();
    addTearDown(() async {
      f.container.dispose();
      await f.db.close();
    });
    await f.db.customStatement(
      "CREATE TRIGGER fail_receipt BEFORE INSERT ON family_meal_decision_receipts BEGIN SELECT RAISE(ABORT, 'forced receipt failure'); END",
    );
    await expectLater(
      f.container.read(acceptRemoteMealDecisionProvider)(
        request(),
        startMeal: true,
      ),
      throwsA(anything),
    );
    expect((await f.db.mealDao.getMealById(1))?.status, 'planned');
    expect(await f.results.loadMealAdvice(1), isNull);
    expect(
      await f.db
          .customSelect('SELECT * FROM family_meal_decision_receipts')
          .get(),
      isEmpty,
    );
  });

  test(
    'receipt write failure rolls back the advice in the same transaction',
    () async {
      final f = await fixture();
      addTearDown(() async {
        f.container.dispose();
        await f.db.close();
      });
      await f.db.customStatement(
        "CREATE TRIGGER fail_receipt BEFORE INSERT ON family_meal_decision_receipts BEGIN SELECT RAISE(ABORT, 'forced receipt failure'); END",
      );
      await expectLater(
        f.container.read(acceptRemoteMealDecisionProvider)(request()),
        throwsA(anything),
      );
      expect(await f.results.loadMealAdvice(1), isNull);
      expect(
        await f.db
            .customSelect('SELECT * FROM family_meal_decision_receipts')
            .get(),
        isEmpty,
      );
      expect(f.calls.where((call) => call['action'] == 'acknowledge'), isEmpty);
    },
  );

  test(
    'an uncommitted reservation cannot apply an expired caregiver decision',
    () async {
      final f = await fixture();
      addTearDown(() async {
        f.container.dispose();
        await f.db.close();
      });
      final stale = MealDecisionRemoteRequest({
        ...request().data,
        'deadline': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      });
      await expectLater(
        f.container.read(acceptRemoteMealDecisionProvider)(stale),
        throwsStateError,
      );
      expect(await f.results.loadMealAdvice(1), isNull);
      expect(
        await f.db
            .customSelect('SELECT * FROM family_meal_decision_receipts')
            .get(),
        isEmpty,
      );
      expect(
        f.calls.where((c) => c['action'] == 'abortAcceptance'),
        hasLength(1),
      );
    },
  );

  test('a changed meal revision leaves neither advice nor receipt', () async {
    final f = await fixture();
    addTearDown(() async {
      f.container.dispose();
      await f.db.close();
    });
    await expectLater(
      f.container.read(acceptRemoteMealDecisionProvider)(request(revision: 2)),
      throwsStateError,
    );
    expect(await f.results.loadMealAdvice(1), isNull);
    expect(
      await f.db
          .customSelect('SELECT * FROM family_meal_decision_receipts')
          .get(),
      isEmpty,
    );
  });

  for (final mismatch in ['account', 'mode', 'source']) {
    test('$mismatch mismatch leaves neither advice nor receipt', () async {
      final f = await fixture(
        uid: mismatch == 'account' ? 'other' : 'child',
        localSource: mismatch == 'source' ? 'other-source' : source,
        mode: mismatch == 'mode'
            ? ApplicationDeviceMode.caregiver
            : ApplicationDeviceMode.patient,
      );
      addTearDown(() async {
        f.container.dispose();
        await f.db.close();
      });
      await expectLater(
        f.container.read(acceptRemoteMealDecisionProvider)(request()),
        throwsStateError,
      );
      expect(await f.results.loadMealAdvice(1), isNull);
      expect(
        await f.db
            .customSelect('SELECT * FROM family_meal_decision_receipts')
            .get(),
        isEmpty,
      );
    });
  }
}
