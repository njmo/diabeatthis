import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/temporary_targets/owned_temp_target.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_operation.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_proposal.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_operation_repository.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    hide TempTargetOperation, TemporaryTarget;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = 'https://example.com';
  const requestId = 'activity-initial';
  final targetStart = DateTime.utc(2026, 10, 29, 13);
  final actualEnd = targetStart.add(const Duration(minutes: 20));
  final delayedCleanup = targetStart.add(const Duration(hours: 2));
  late DatabaseImpl db;
  late TempTargetOperationRepository repository;
  late SharedPreferences prefs;
  late MockClient client;
  late List<Map<String, dynamic>> remoteEntries;
  late List<Map<String, dynamic>> posted;
  late List<Uri> reads;
  late int logId;

  TempTargetService service() => TempTargetService(
    preferences: () async => prefs,
    database: () => db,
    writer: NightscoutTempTargetWriter(client: client),
  );

  Map<String, dynamic> treatment({
    required String id,
    required DateTime start,
    String enteredBy = 'Diabeatthis',
    int minutes = 90,
    int target = 140,
  }) => {
    '_id': id,
    'eventType': 'Temporary Target',
    'created_at': start.toIso8601String(),
    'date': start.millisecondsSinceEpoch,
    'duration': minutes,
    'targetBottom': target,
    'targetTop': target,
    'units': 'mg/dl',
    'enteredBy': enteredBy,
  };

  Future<void> confirmOwned({DateTime? startedAt}) async {
    final start = startedAt ?? targetStart;
    final owned = OwnedTempTarget(
      entityId: logId,
      targetType: 'activity',
      source: source,
      startedAt: start,
      until: start.add(const Duration(minutes: 90)),
      target: 140,
      durationMinutes: 90,
      nightscoutId: 'owned-target',
    );
    await repository.createOffer(
      TempTargetProposal(
        id: requestId,
        entityId: logId,
        targetType: 'activity',
        target: 140,
        durationMinutes: 90,
        expiresAt: start.add(const Duration(minutes: 15)),
        source: source,
      ),
      now: start,
    );
    expect(await repository.claimStart(requestId, owned, now: start), isTrue);
    expect(
      await repository.markSent(requestId, confirmed: owned, now: start),
      isTrue,
    );
    remoteEntries.add(treatment(id: 'owned-target', start: start));
  }

  Future<void> finishAt(DateTime end) async {
    await (db.update(
      db.activityLog,
    )..where((row) => row.id.equals(logId))).write(
      ActivityLogCompanion(endedAt: Value(end.millisecondsSinceEpoch)),
    );
  }

  void expectStopAt(DateTime expected) {
    expect(posted, hasLength(1));
    final stop = posted.single;
    expect(stop['eventType'], 'Temporary Target');
    expect(stop['duration'], 0);
    expect(stop['enteredBy'], 'Diabeatthis');
    expect(stop['date'], expected.millisecondsSinceEpoch);
    expect(DateTime.parse(stop['created_at'] as String), expected);
    expect(stop.containsKey('targetBottom'), isFalse);
    expect(stop.containsKey('targetTop'), isFalse);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: source,
      nightscoutTokenKey: 'test-token',
      nightscoutTempTargetsEnabledKey: true,
    });
    prefs = await SharedPreferences.getInstance();
    db = DatabaseImpl(NativeDatabase.memory());
    repository = TempTargetOperationRepository(db);
    final activityId = await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'Run',
            percentagePre: 0,
            percentagePost: 0,
            durationMinutes: const Value(60),
          ),
        );
    logId = await db
        .into(db.activityLog)
        .insert(
          ActivityLogCompanion.insert(
            activityId: activityId,
            startedAt: targetStart.millisecondsSinceEpoch,
          ),
        );
    remoteEntries = [];
    posted = [];
    reads = [];
    client = MockClient((request) async {
      if (request.method == 'GET') {
        reads.add(request.url);
        // Return the whole remote list so client-side timestamp filtering is
        // exercised even if the server ignores its query boundary.
        return http.Response(jsonEncode(remoteEntries), 200);
      }
      expect(request.method, 'POST');
      posted.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('[{"_id":"stop-record"}]', 201);
    });
  });
  tearDown(() async {
    client.close();
    await db.close();
  });

  test(
    'delayed cleanup uses the persisted actual ending even after the target expires',
    () async {
      await confirmOwned();
      await finishAt(actualEnd);
      expect((await repository.get(requestId))!.closedAt, actualEnd);

      final result = await withClock(
        Clock.fixed(delayedCleanup),
        () => service().stopFinishedActivityTarget(),
      );

      expect(result, TempTargetSendResult.sent);
      expectStopAt(actualEnd);
      expect((await repository.get('$requestId:stop'))!.stoppedAt, actualEnd);
      expect(
        (await repository.get(requestId))!.status,
        TempTargetOperationStatus.completed,
      );
      expect(
        DateTime.parse(
          reads.single.queryParameters['find[created_at][\$lte]']!,
        ),
        actualEnd.add(const Duration(milliseconds: 999)),
      );
    },
  );

  test(
    'a future-dated remote target does not hide the owner at closure',
    () async {
      await confirmOwned();
      await finishAt(actualEnd);
      remoteEntries.insert(
        0,
        treatment(
          id: 'scheduled-future',
          start: delayedCleanup.add(const Duration(hours: 1)),
          enteredBy: 'AndroidAPS',
          target: 160,
        ),
      );

      final result = await withClock(
        Clock.fixed(delayedCleanup),
        () => service().stopFinishedActivityTarget(),
      );

      expect(result, TempTargetSendResult.sent);
      expectStopAt(actualEnd);
    },
  );

  test(
    'a manual replacement after closure is preserved by a historical stop',
    () async {
      await confirmOwned();
      await finishAt(actualEnd);
      final replacementAt = actualEnd.add(const Duration(minutes: 5));
      remoteEntries.insert(
        0,
        treatment(
          id: 'manual-replacement',
          start: replacementAt,
          enteredBy: 'AndroidAPS',
          target: 160,
        ),
      );

      final result = await withClock(
        Clock.fixed(delayedCleanup),
        () => service().stopFinishedActivityTarget(),
      );

      expect(result, TempTargetSendResult.sent);
      expectStopAt(actualEnd);
      expect(
        DateTime.parse(
          posted.single['created_at'] as String,
        ).isBefore(replacementAt),
        isTrue,
      );
    },
  );

  for (final offset in [500, 999]) {
    test(
      'a manual replacement $offset ms after closure blocks a colliding stop',
      () async {
        await confirmOwned();
        await finishAt(actualEnd);
        remoteEntries.insert(
          0,
          treatment(
            id: 'manual-replacement',
            start: actualEnd.add(Duration(milliseconds: offset)),
            enteredBy: 'AndroidAPS',
            target: 160,
          ),
        );

        final result = await withClock(
          Clock.fixed(delayedCleanup),
          () => service().stopFinishedActivityTarget(),
        );

        expect(result, TempTargetSendResult.ignored);
        expect(posted, isEmpty);
        expect(await repository.get('$requestId:stop'), isNull);
        expect(await repository.latestOwned(), isNull);
      },
    );
  }

  test(
    'a manual replacement exactly one second after closure remains separate',
    () async {
      await confirmOwned();
      await finishAt(actualEnd);
      remoteEntries.insert(
        0,
        treatment(
          id: 'manual-replacement',
          start: actualEnd.add(const Duration(seconds: 1)),
          enteredBy: 'AndroidAPS',
          target: 160,
        ),
      );

      final result = await withClock(
        Clock.fixed(delayedCleanup),
        () => service().stopFinishedActivityTarget(),
      );

      expect(result, TempTargetSendResult.sent);
      expectStopAt(actualEnd);
    },
  );

  test(
    'observed external activity coverage never grants cancellation ownership',
    () async {
      final external = TemporaryTarget(
        nightscoutId: 'external-target',
        createdAt: targetStart,
        durationInMiliseconds: const Duration(minutes: 90).inMilliseconds,
        duration: 90,
        targetBottom: 160,
        targetTop: 160,
      );
      expect(
        await withClock(
          Clock.fixed(targetStart),
          () => service().activityOffer(logId, activeTarget: external),
        ),
        isNull,
      );
      await finishAt(actualEnd);

      final result = await withClock(
        Clock.fixed(delayedCleanup),
        () => service().stopFinishedActivityTarget(),
      );

      expect(result, TempTargetSendResult.ignored);
      expect(await repository.latestOwned(), isNull);
      expect(await repository.list(), isEmpty);
      expect(reads, isEmpty);
      expect(posted, isEmpty);
    },
  );

  test(
    'deleting a finished log retains its original closure for later cleanup',
    () async {
      await confirmOwned();
      await finishAt(actualEnd);
      await (db.delete(
        db.activityLog,
      )..where((row) => row.id.equals(logId))).go();
      expect((await repository.get(requestId))!.closedAt, actualEnd);

      final result = await withClock(
        Clock.fixed(delayedCleanup),
        () => service().stopFinishedActivityTarget(),
      );

      expect(result, TempTargetSendResult.sent);
      expectStopAt(actualEnd);
      expect((await repository.get(requestId))!.closedAt, actualEnd);
    },
  );

  test(
    'deleting an unfinished log persists a stable stop time before cleanup starts',
    () async {
      await confirmOwned(
        startedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
      );
      await (db.delete(
        db.activityLog,
      )..where((row) => row.id.equals(logId))).go();
      final closedAt = (await repository.get(requestId))!.closedAt!;
      final cleanup = closedAt.add(const Duration(minutes: 10));

      final result = await withClock(
        Clock.fixed(cleanup),
        () => service().stopFinishedActivityTarget(),
      );

      expect(result, TempTargetSendResult.sent);
      expectStopAt(closedAt);
      expect((await repository.get(requestId))!.closedAt, closedAt);
      expect((await repository.get('$requestId:stop'))!.stoppedAt, closedAt);
    },
  );
}
