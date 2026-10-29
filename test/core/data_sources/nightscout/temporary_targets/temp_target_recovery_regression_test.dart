import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/temporary_targets/owned_temp_target.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_operation.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_operation_repository.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    hide TempTargetOperation;
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = 'https://nightscout.example';
  late DateTime now;
  late DatabaseImpl db;
  late SharedPreferences preferences;
  late TempTargetOperationRepository operations;
  late NightscoutTempTargetWriter writer;
  late TempTargetService service;
  late List<Map<String, dynamic>> postRequests;
  late List<Map<String, dynamic>> remoteTreatments;
  late String postMode;
  late int readRequests;

  TempTargetService createService() => TempTargetService(
    preferences: () async => preferences,
    database: () => db,
    writer: writer,
  );

  Future<int> activity() async {
    final activityId = await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'Jujitsu',
            percentagePre: 0,
            percentagePost: 0,
            durationMinutes: const Value(60),
          ),
        );
    return db
        .into(db.activityLog)
        .insert(
          ActivityLogCompanion.insert(
            activityId: activityId,
            startedAt: now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
          ),
        );
  }

  Future<TempTargetSendResult> approve(TempTargetNotificationEvent event) =>
      service.respond(
        requestId: event.requestId!,
        targetType: event.targetType,
        entityId: event.entityId,
        approved: true,
      );

  setUp(() async {
    now = DateTime(2026, 10, 29, 12);
    postRequests = [];
    remoteTreatments = [];
    postMode = 'success';
    readRequests = 0;
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: source,
      nightscoutTokenKey: 'write-token',
      nightscoutTempTargetsEnabledKey: true,
    });
    preferences = await SharedPreferences.getInstance();
    db = DatabaseImpl(NativeDatabase.memory());
    operations = TempTargetOperationRepository(db);
    writer = NightscoutTempTargetWriter(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          readRequests++;
          return http.Response(jsonEncode(remoteTreatments), 200);
        }
        expect(request.method, 'POST');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        postRequests.add(payload);
        if (postMode == 'forbidden') return http.Response('', 403);
        if (postMode == 'networkAbsent') {
          throw http.ClientException('Connection lost');
        }
        remoteTreatments.add({
          ...payload,
          '_id': 'remote-${postRequests.length}',
        });
        if (postMode == 'networkAccepted') {
          throw http.ClientException('Response lost');
        }
        if (postMode == 'serverAccepted') return http.Response('', 503);
        if (postMode == 'timeoutAccepted') return http.Response('', 408);
        if (postMode == 'conflictAccepted') return http.Response('', 409);
        return http.Response(jsonEncode(remoteTreatments.last), 201);
      }),
    );
    service = createService();
  });

  tearDown(() => db.close());

  test(
    'an activity offer awaiting delivery survives a service restart with the same request',
    () => withClock(Clock(() => now), () async {
      final logId = await activity();
      final first = (await service.activityOffer(logId))!;
      expect(
        (await operations.get(first.requestId!))!.status,
        TempTargetOperationStatus.pendingDelivery,
      );
      service = createService();
      final recovered = (await service.activityOffer(logId))!;
      expect(recovered.requestId, first.requestId);
      expect(recovered.durationMinutes, 120);
      expect(await operations.list(), hasLength(1));
      expect(postRequests, isEmpty);
    }),
  );

  test(
    'failed notification delivery releases the same request and successful delivery prevents repeats',
    () => withClock(Clock(() => now), () async {
      final logId = await activity();
      final first = (await service.activityOffer(logId))!;
      expect(await service.activityOffer(logId), isNull);
      service.deliveryFailed(first.requestId!);
      final retry = (await service.activityOffer(logId))!;
      expect(retry.requestId, first.requestId);
      await service.markDelivered(retry.requestId!);
      expect(
        (await operations.get(first.requestId!))!.status,
        TempTargetOperationStatus.awaitingConsent,
      );
      expect(await service.activityOffer(logId), isNull);
      service = createService();
      expect(await service.activityOffer(logId), isNull);
      expect(await operations.list(), hasLength(1));
      expect(postRequests, isEmpty);
    }),
  );

  test(
    'a meal prompt interrupted before delivery is recovered once after restart',
    () => withClock(Clock(() => now), () async {
      final mealId = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Meal',
              plannedAt: now
                  .add(const Duration(minutes: 15))
                  .millisecondsSinceEpoch,
            ),
          );
      final first = (await service.prepare(
        TempTargetNotificationEvent.meal(entityId: mealId),
      ))!;
      service = createService();
      final pending = await service.pendingMealOffers();
      expect(pending.single.requestId, first.requestId);
      service.deliveryFailed(pending.single.requestId!);
      expect(
        (await service.pendingMealOffers()).single.requestId,
        first.requestId,
      );
      await service.markDelivered(first.requestId!);
      service = createService();
      expect(await service.pendingMealOffers(), isEmpty);
      expect(
        await service.prepare(
          TempTargetNotificationEvent.meal(entityId: mealId),
        ),
        isNull,
      );
      expect(postRequests, isEmpty);
    }),
  );

  test(
    'an explicit 403 requires a new offer and new approval before another POST',
    () => withClock(Clock(() => now), () async {
      final logId = await activity();
      final first = (await service.activityOffer(logId))!;
      await service.markDelivered(first.requestId!);
      postMode = 'forbidden';
      expect(await approve(first), TempTargetSendResult.failed);
      expect(
        (await operations.get(first.requestId!))!.status,
        TempTargetOperationStatus.rejected,
      );
      expect(await approve(first), TempTargetSendResult.ignored);
      service = createService();
      now = now.add(const Duration(seconds: 2));
      final fresh = (await service.activityOffer(logId))!;
      expect(fresh.requestId, isNot(first.requestId));
      expect(postRequests, hasLength(1));
      expect(
        (await operations.get(fresh.requestId!))!.status,
        TempTargetOperationStatus.pendingDelivery,
      );
      expect(await approve(first), TempTargetSendResult.ignored);
      expect(postRequests, hasLength(1));
      postMode = 'success';
      await service.markDelivered(fresh.requestId!);
      expect(await approve(fresh), TempTargetSendResult.sent);
      expect(postRequests, hasLength(2));
      expect(
        (await operations.get(fresh.requestId!))!.status,
        TempTargetOperationStatus.sent,
      );
      expect(
        (await operations.latestOwned(source: source))!.nightscoutId,
        'remote-2',
      );
    }),
  );

  for (final failure in [
    'serverAccepted',
    'networkAccepted',
    'timeoutAccepted',
    'conflictAccepted',
  ]) {
    test(
      '$failure is recovered as sent after restart without a duplicate POST',
      () => withClock(Clock(() => now), () async {
        final logId = await activity();
        final offer = (await service.activityOffer(logId))!;
        await service.markDelivered(offer.requestId!);
        postMode = failure;
        expect(await approve(offer), TempTargetSendResult.failed);
        expect(
          (await operations.get(offer.requestId!))!.status,
          TempTargetOperationStatus.unknownResult,
        );
        expect(remoteTreatments, hasLength(1));
        expect(await operations.latestOwned(source: source), isNull);
        service = createService();
        postMode = 'success';
        now = now.add(const Duration(seconds: 2));
        expect(await service.activityOffer(logId), isNull);
        expect(
          (await operations.get(offer.requestId!))!.status,
          TempTargetOperationStatus.sent,
        );
        final owned = (await operations.latestOwned(source: source))!;
        expect(owned.nightscoutId, 'remote-1');
        expect(
          owned.startedAt.millisecondsSinceEpoch,
          postRequests.single['date'],
        );
        expect(await approve(offer), TempTargetSendResult.ignored);
        expect(postRequests, hasLength(1));
        expect(readRequests, greaterThan(0));
      }),
    );
  }

  test(
    'a crash after HTTP acceptance and before local confirmation recovers the persisted attempt',
    () => withClock(Clock(() => now), () async {
      final logId = await activity();
      final offer = (await service.activityOffer(logId))!;
      final attempted = OwnedTempTarget(
        entityId: logId,
        targetType: offer.targetType,
        source: source,
        startedAt: now,
        until: now.add(Duration(minutes: offer.durationMinutes!)),
        target: offer.target!,
        durationMinutes: offer.durationMinutes!,
      );
      expect(
        await operations.claimStart(offer.requestId!, attempted, now: now),
        isTrue,
      );
      await writer.send(
        url: source,
        token: 'write-token',
        startsAt: attempted.startedAt,
        target: attempted.target,
        durationMinutes: attempted.durationMinutes,
        reason: 'Activity',
      );
      expect(
        (await operations.get(offer.requestId!))!.status,
        TempTargetOperationStatus.sending,
      );
      expect(await operations.latestOwned(source: source), isNull);
      service = createService();
      now = now.add(const Duration(seconds: 2));
      expect(await service.activityOffer(logId), isNull);
      expect(
        (await operations.get(offer.requestId!))!.status,
        TempTargetOperationStatus.sent,
      );
      expect(
        (await operations.latestOwned(source: source))!.nightscoutId,
        'remote-1',
      );
      expect(postRequests, hasLength(1));
    }),
  );

  test(
    'an unknown absent write stays unresolved and never repeats automatically',
    () => withClock(Clock(() => now), () async {
      final logId = await activity();
      final offer = (await service.activityOffer(logId))!;
      postMode = 'networkAbsent';
      expect(await approve(offer), TempTargetSendResult.failed);
      expect(remoteTreatments, isEmpty);
      service = createService();
      postMode = 'success';
      now = now.add(const Duration(seconds: 2));
      expect(await service.activityOffer(logId), isNull);
      expect(await approve(offer), TempTargetSendResult.ignored);
      service = createService();
      now = now.add(const Duration(minutes: 1));
      expect(await service.activityOffer(logId), isNull);
      expect(
        (await operations.get(offer.requestId!))!.status,
        TempTargetOperationStatus.unknownResult,
      );
      expect(await operations.latestOwned(source: source), isNull);
      expect(postRequests, hasLength(1));
      expect(readRequests, greaterThanOrEqualTo(2));
    }),
  );
}
