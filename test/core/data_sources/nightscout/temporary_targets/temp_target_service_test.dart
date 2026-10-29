import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' hide TemporaryTarget;
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
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
  late List<Map<String, dynamic>> sent;
  late bool fail;

  TempTargetService createService() => TempTargetService(
    preferences: () async => prefs,
    database: () => db,
    writer: NightscoutTempTargetWriter(
      client: MockClient((request) async {
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('', fail ? 403 : 201);
      }),
    ),
  );

  setUp(() async {
    now = DateTime(2026, 10, 29, 17, 30);
    sent = [];
    fail = false;
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: 'https://example.com',
      nightscoutTokenKey: 'write-token',
      nightscoutTempTargetsEnabledKey: true,
    });
    prefs = await SharedPreferences.getInstance();
    db = DatabaseImpl(NativeDatabase.memory());
    service = createService();
  });
  tearDown(() => db.close());

  Future<int> activity({int? minutes, DateTime? start}) async {
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
            startedAt:
                (start ?? DateTime(2026, 10, 29, 18)).millisecondsSinceEpoch,
          ),
        );
  }

  Future<TempTargetSendResult> respond(
    TempTargetNotificationEvent offer, {
    bool approve = true,
  }) => service.respond(
    requestId: offer.requestId!,
    targetType: offer.targetType,
    entityId: offer.entityId,
    approved: approve,
  );

  test(
    'meal offer sends 90 for 45 minutes only after confirmation and once',
    () => withClock(Clock(() => now), () async {
      final id = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Meal',
              plannedAt: now
                  .add(const Duration(minutes: 15))
                  .millisecondsSinceEpoch,
            ),
          );
      final offer = (await service.prepare(
        TempTargetNotificationEvent.meal(entityId: id),
      ))!;
      expect(sent, isEmpty);
      expect(offer.target, 90);
      expect(offer.durationMinutes, 45);
      expect(await respond(offer), TempTargetSendResult.sent);
      expect(await respond(offer), TempTargetSendResult.ignored);
      service = createService();
      expect(await respond(offer), TempTargetSendResult.ignored);
      expect(sent.single['duration'], 45);
      expect(sent.single['reason'], 'Eating Soon');
    }),
  );

  test(
    'scheduled activity starts at minus 60 and late approval ends at planned end',
    () => withClock(Clock(() => now), () async {
      final id = await activity(minutes: 60);
      now = now.subtract(const Duration(minutes: 30));
      now = now.subtract(const Duration(minutes: 1));
      expect(await service.activityOffer(id), isNull);
      now = now.add(const Duration(minutes: 1));
      final offer = (await service.activityOffer(id))!;
      expect(offer.target, 140);
      expect(offer.durationMinutes, 120);
      expect(sent, isEmpty);
      now = now.add(const Duration(minutes: 15));
      expect(await respond(offer), TempTargetSendResult.sent);
      expect(sent.single['duration'], 105);
      expect(await service.activityOffer(id), isNull);
    }),
  );

  test(
    'manual activity first asks thirty minutes after start and renews only on confirmation',
    () => withClock(Clock(() => now), () async {
      final id = await activity();
      final offer = (await service.activityOffer(id))!;
      await respond(offer);
      now = now.add(const Duration(minutes: 59));
      expect(await service.activityOffer(id), isNull);
      now = now.add(const Duration(minutes: 1));
      service = createService();
      final renewal = (await service.activityOffer(id))!;
      expect(renewal.renewal, isTrue);
      expect(renewal.durationMinutes, 90);
      expect(sent, hasLength(1));
      expect(await service.activityOffer(id), isNull);
      expect(await respond(renewal), TempTargetSendResult.sent);
      expect(sent, hasLength(2));
      expect(sent.last['date'], now.millisecondsSinceEpoch);
      expect(sent.last['duration'], 90);
    }),
  );

  test(
    'rejection and no response never extend a manual activity target',
    () => withClock(Clock(() => now), () async {
      final id = await activity();
      final offer = (await service.activityOffer(id))!;
      await respond(offer);
      now = now.add(const Duration(minutes: 80));
      final renewal = (await service.activityOffer(id))!;
      await respond(renewal, approve: false);
      now = now.add(const Duration(minutes: 20));
      expect(await service.activityOffer(id), isNull);
      expect(await respond(renewal), TempTargetSendResult.ignored);
      expect(sent, hasLength(1));
    }),
  );

  test(
    'closed activities, expired offers, disabled setting and removed token cannot send',
    () => withClock(Clock(() => now), () async {
      final id = await activity();
      final offer = (await service.activityOffer(id))!;
      await prefs.setBool(nightscoutTempTargetsEnabledKey, false);
      expect(await respond(offer), TempTargetSendResult.expired);
      await prefs.setBool(nightscoutTempTargetsEnabledKey, true);
      await prefs.remove(nightscoutTokenKey);
      expect(await respond(offer), TempTargetSendResult.expired);
      await prefs.setString(nightscoutTokenKey, 'write-token');
      await db.activityDao.finishActivityLogIfOpen(
        id,
        DateTime(2026, 10, 29, 18),
        DateTime(2026, 10, 29, 18, 1),
      );
      expect(await respond(offer), TempTargetSendResult.expired);
      expect(sent, isEmpty);
    }),
  );

  test(
    'expired approval does not send and failures are not retried',
    () => withClock(Clock(() => now), () async {
      final id = await activity();
      final offer = (await service.activityOffer(id))!;
      now = now.add(const Duration(minutes: 61));
      expect(await respond(offer), TempTargetSendResult.expired);
      now = now.subtract(const Duration(minutes: 61));
      fail = true;
      expect(await respond(offer), TempTargetSendResult.failed);
      expect(await respond(offer), TempTargetSendResult.ignored);
      expect(sent, hasLength(1));
    }),
  );

  test(
    'existing matching activity target with full coverage needs no replacement',
    () => withClock(Clock(() => now), () async {
      final id = await activity(minutes: 60);
      expect(
        await service.activityOffer(
          id,
          activeTarget: TemporaryTarget(
            nightscoutId: 'existing',
            createdAt: now,
            durationInMiliseconds: 5400000,
            duration: 90,
            targetBottom: 140,
            targetTop: 140,
          ),
        ),
        isNull,
      );
      expect(sent, isEmpty);
    }),
  );

  test(
    'disabled option keeps legacy reminders without write authorization',
    () => withClock(Clock(() => now), () async {
      await prefs.setBool(nightscoutTempTargetsEnabledKey, false);
      final reminder = TempTargetNotificationEvent.meal(entityId: 1);
      expect(await service.prepare(reminder), same(reminder));
      expect(reminder.requestId, isNull);
      expect(await service.activityOffer(1), isNull);
      expect(sent, isEmpty);
    }),
  );
}
