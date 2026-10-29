import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' hide TemporaryTarget;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseImpl db;
  late SharedPreferences prefs;
  late TempTargetService service;
  late DateTime now;
  late DateTime start;
  late List<Map<String, dynamic>> posts;
  late Map<String, dynamic>? remote;
  late int readStatus;
  late int stopStatus;
  late int reads;

  TempTargetService createService() => TempTargetService(
    preferences: () async => prefs,
    database: () => db,
    writer: NightscoutTempTargetWriter(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          reads++;
          expect(
            request.url.queryParameters['find[eventType]'],
            'Temporary Target',
          );
          return http.Response(
            jsonEncode(remote == null ? [] : [remote]),
            readStatus,
          );
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        posts.add(body);
        if (body['duration'] == 0) return http.Response('', stopStatus);
        remote = {...body, '_id': 'owned-target'};
        return http.Response(jsonEncode([remote]), 201);
      }),
    ),
  );

  setUp(() async {
    now = DateTime(2026, 10, 29, 17, 30);
    start = DateTime(2026, 10, 29, 18);
    posts = [];
    remote = null;
    reads = 0;
    readStatus = 200;
    stopStatus = 201;
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: 'https://example.com',
      nightscoutTokenKey: 'token',
      nightscoutTempTargetsEnabledKey: true,
    });
    prefs = await SharedPreferences.getInstance();
    db = DatabaseImpl(NativeDatabase.memory());
    service = createService();
  });
  tearDown(() => db.close());

  Future<int> activity({int? minutes}) async {
    final id = await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'Walk',
            percentagePre: 0,
            percentagePost: 0,
            durationMinutes: Value(minutes),
          ),
        );
    return db
        .into(db.activityLog)
        .insert(
          ActivityLogCompanion.insert(
            activityId: id,
            startedAt: start.millisecondsSinceEpoch,
          ),
        );
  }

  Future<int> startOwned({int? minutes}) async {
    final id = await activity(minutes: minutes);
    final offer = (await service.activityOffer(id))!;
    expect(
      await service.respond(
        requestId: offer.requestId!,
        targetType: offer.targetType,
        entityId: id,
        approved: true,
      ),
      TempTargetSendResult.sent,
    );
    return id;
  }

  Future<void> finish(int id) async {
    now = start.add(const Duration(minutes: 15));
    expect(
      await db.activityDao.finishActivityLogIfOpen(id, start, now),
      isTrue,
    );
  }

  for (final minutes in <int?>[null, 60]) {
    test(
      'finishing activity with duration $minutes stops its target after restart',
      () => withClock(Clock(() => now), () async {
        final id = await startOwned(minutes: minutes);
        await finish(id);
        service = createService();
        expect(
          await service.stopFinishedActivityTarget(),
          TempTargetSendResult.sent,
        );
        expect(posts, hasLength(2));
        expect(posts.last, {
          'eventType': 'Temporary Target',
          'created_at': now.toUtc().toIso8601String(),
          'date': now.millisecondsSinceEpoch,
          'duration': 0,
          'enteredBy': 'Diabeatthis',
        });
        expect(
          await service.stopFinishedActivityTarget(),
          TempTargetSendResult.ignored,
        );
        expect(posts, hasLength(2));
      }),
    );
  }

  test(
    'an ongoing activity never cancels its target',
    () => withClock(Clock(() => now), () async {
      await startOwned(minutes: 60);
      now = start.add(const Duration(minutes: 15));
      expect(
        await service.stopFinishedActivityTarget(),
        TempTargetSendResult.ignored,
      );
      expect(reads, 0);
      expect(posts, hasLength(1));
    }),
  );

  test(
    'a later target is preserved even when its target value is also 140',
    () => withClock(Clock(() => now), () async {
      final id = await startOwned(minutes: 60);
      await finish(id);
      remote = {
        ...remote!,
        '_id': 'manual-replacement',
        'created_at': now
            .subtract(const Duration(minutes: 1))
            .toUtc()
            .toIso8601String(),
        'enteredBy': 'AAPS',
      };
      expect(
        await service.stopFinishedActivityTarget(),
        TempTargetSendResult.ignored,
      );
      expect(reads, 1);
      expect(posts, hasLength(1));
    }),
  );

  test(
    'a naturally expired target needs no cancellation',
    () => withClock(Clock(() => now), () async {
      final id = await startOwned(minutes: 60);
      now = start.add(const Duration(hours: 1));
      await db.activityDao.finishActivityLogIfOpen(id, start, now);
      expect(
        await service.stopFinishedActivityTarget(),
        TempTargetSendResult.ignored,
      );
      expect(reads, 0);
      expect(posts, hasLength(1));
    }),
  );

  test(
    'an observed external target does not establish ownership',
    () => withClock(Clock(() => now), () async {
      final id = await activity(minutes: 60);
      expect(
        await service.activityOffer(
          id,
          activeTarget: TemporaryTarget(
            nightscoutId: 'external',
            createdAt: now,
            durationInMiliseconds: 5400000,
            duration: 90,
            targetBottom: 140,
            targetTop: 140,
          ),
        ),
        isNull,
      );
      await finish(id);
      expect(
        await service.stopFinishedActivityTarget(),
        TempTargetSendResult.ignored,
      );
      expect(reads, 0);
      expect(posts, isEmpty);
    }),
  );

  test(
    'verification failure cannot send a cancellation',
    () => withClock(Clock(() => now), () async {
      final id = await startOwned(minutes: 60);
      await finish(id);
      readStatus = 403;
      expect(
        await service.stopFinishedActivityTarget(),
        TempTargetSendResult.failed,
      );
      expect(posts, hasLength(1));
    }),
  );

  test(
    'uncertain cancellation is not repeated after restart',
    () => withClock(Clock(() => now), () async {
      final id = await startOwned(minutes: 60);
      await finish(id);
      stopStatus = 503;
      expect(
        await service.stopFinishedActivityTarget(),
        TempTargetSendResult.failed,
      );
      service = createService();
      expect(
        await service.stopFinishedActivityTarget(),
        TempTargetSendResult.ignored,
      );
      expect(posts, hasLength(2));
    }),
  );

  test(
    'changing the Nightscout connection cannot cancel a target on another site',
    () => withClock(Clock(() => now), () async {
      final id = await startOwned(minutes: 60);
      await finish(id);
      await prefs.setString(nightscoutUrlKey, 'https://other.example.com');
      expect(
        await service.stopFinishedActivityTarget(),
        TempTargetSendResult.ignored,
      );
      expect(reads, 0);
      expect(posts, hasLength(1));
    }),
  );
}
