import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
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
  late DatabaseImpl db;
  late SharedPreferences prefs;
  late TempTargetService service;
  late TempTargetOperationRepository operations;
  late DateTime now;
  late List<Map<String, dynamic>> posts;
  late List<Map<String, dynamic>> remote;
  late int mealStatus;
  Completer<http.Response>? firstResponse;
  Completer<void>? firstPostStarted;

  TempTargetService createService() => TempTargetService(
    preferences: () async => prefs,
    database: () => db,
    writer: NightscoutTempTargetWriter(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode(remote), 200);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        posts.add(body);
        if (firstResponse != null && posts.length == 1) {
          firstPostStarted!.complete();
          return firstResponse!.future;
        }
        if (body['reason'] == 'Eating Soon' && mealStatus != 201) {
          return http.Response('', mealStatus);
        }
        final entry = {...body, '_id': 'remote-${posts.length}'};
        remote.add(entry);
        return http.Response(jsonEncode([entry]), 201);
      }),
    ),
  );

  setUp(() async {
    now = DateTime(2026, 10, 29, 12);
    posts = [];
    remote = [];
    mealStatus = 201;
    firstResponse = null;
    firstPostStarted = null;
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: 'https://example.com',
      nightscoutTokenKey: 'write-token',
      nightscoutTempTargetsEnabledKey: true,
    });
    prefs = await SharedPreferences.getInstance();
    db = DatabaseImpl(NativeDatabase.memory());
    operations = TempTargetOperationRepository(db);
    service = createService();
  });
  tearDown(() => db.close());

  Future<int> activity({DateTime? start}) async {
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
            startedAt: (start ?? now.add(const Duration(hours: 1)))
                .millisecondsSinceEpoch,
          ),
        );
  }

  Future<TempTargetNotificationEvent> meal() async {
    final id = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Meal',
            plannedAt: now.millisecondsSinceEpoch,
          ),
        );
    return (await service.prepare(
      TempTargetNotificationEvent.meal(entityId: id),
    ))!;
  }

  Future<TempTargetSendResult> approve(TempTargetNotificationEvent event) =>
      service.respond(
        requestId: event.requestId!,
        targetType: event.targetType,
        entityId: event.entityId,
        approved: true,
      );

  test(
    'a second rapid approval is offered again after restart and needs new consent',
    () => withClock(Clock(() => now), () async {
      final logId = await activity();
      final mealOffer = await meal();
      final activityOffer = (await service.activityOffer(logId))!;
      await service.markDelivered(mealOffer.requestId!);
      await service.markDelivered(activityOffer.requestId!);
      expect(await approve(mealOffer), TempTargetSendResult.sent);
      expect(await approve(activityOffer), TempTargetSendResult.deferred);
      final deferred = (await operations.get(activityOffer.requestId!))!;
      expect(deferred.status, TempTargetOperationStatus.pendingDelivery);
      expect(deferred.deliveredAt, isNull);
      expect(deferred.attemptedTarget, isNull);
      expect(posts, hasLength(1));
      service = createService();
      now = now.add(const Duration(seconds: 2));
      final again = (await service.activityOffer(logId))!;
      expect(again.requestId, activityOffer.requestId);
      expect(posts, hasLength(1));
      await service.markDelivered(again.requestId!);
      expect(await approve(again), TempTargetSendResult.sent);
      expect(await approve(again), TempTargetSendResult.ignored);
      expect(posts, hasLength(2));
    }),
  );

  test(
    'a deferred meal returns through pending deliveries without an automatic write',
    () => withClock(Clock(() => now), () async {
      final logId = await activity();
      final activityOffer = (await service.activityOffer(logId))!;
      final mealOffer = await meal();
      await service.markDelivered(activityOffer.requestId!);
      await service.markDelivered(mealOffer.requestId!);
      expect(await approve(activityOffer), TempTargetSendResult.sent);
      expect(await approve(mealOffer), TempTargetSendResult.deferred);
      now = now.add(const Duration(seconds: 2));
      final again = (await service.pendingMealOffers()).single;
      expect(again.requestId, mealOffer.requestId);
      expect(posts, hasLength(1));
      await service.markDelivered(again.requestId!);
      expect(await approve(again), TempTargetSendResult.sent);
      expect(posts, hasLength(2));
    }),
  );

  test(
    'an in-flight POST defers another approval but never reuses its consent',
    () => withClock(Clock(() => now), () async {
      final logId = await activity();
      final activityOffer = (await service.activityOffer(logId))!;
      final mealOffer = await meal();
      await service.markDelivered(activityOffer.requestId!);
      await service.markDelivered(mealOffer.requestId!);
      firstResponse = Completer<http.Response>();
      firstPostStarted = Completer<void>();
      final sending = approve(mealOffer);
      await firstPostStarted!.future;
      expect(await approve(activityOffer), TempTargetSendResult.deferred);
      expect(
        (await operations.get(activityOffer.requestId!))!.status,
        TempTargetOperationStatus.pendingDelivery,
      );
      expect(posts, hasLength(1));
      firstResponse!.complete(http.Response('', 201));
      expect(await sending, TempTargetSendResult.sent);
      now = now.add(const Duration(seconds: 2));
      final again = (await service.activityOffer(logId))!;
      expect(again.requestId, activityOffer.requestId);
      expect(posts, hasLength(1));
      await service.markDelivered(again.requestId!);
      expect(await approve(again), TempTargetSendResult.sent);
      expect(posts, hasLength(2));
    }),
  );

  test(
    'requeueing consent cannot undo a sent, declined or unknown operation',
    () => withClock(Clock(() => now), () async {
      final sent = await meal();
      expect(await approve(sent), TempTargetSendResult.sent);
      expect(await operations.deferConsent(sent.requestId!), isFalse);
      final logId = await activity();
      final declined = (await service.activityOffer(logId))!;
      await service.respond(
        requestId: declined.requestId!,
        targetType: declined.targetType,
        entityId: logId,
        approved: false,
      );
      expect(await operations.deferConsent(declined.requestId!), isFalse);
      now = now.add(const Duration(seconds: 2));
      await (db.delete(
        db.meal,
      )..where((row) => row.id.equals(sent.entityId))).go();
      final unknown = await meal();
      mealStatus = 503;
      expect(await approve(unknown), TempTargetSendResult.failed);
      expect(await operations.deferConsent(unknown.requestId!), isFalse);
      expect(
        (await operations.get(unknown.requestId!))!.status,
        TempTargetOperationStatus.unknownResult,
      );
    }),
  );

  test(
    'an explicitly rejected nearby start does not block the actual closure timestamp',
    () => withClock(Clock(() => now), () async {
      final logId = await activity(
        start: now.subtract(const Duration(minutes: 10)),
      );
      final ownedOffer = (await service.activityOffer(logId))!;
      expect(await approve(ownedOffer), TempTargetSendResult.sent);
      final startedAt = now.subtract(const Duration(minutes: 10));
      final closedAt = now.add(const Duration(minutes: 10));
      now = closedAt.add(const Duration(milliseconds: 500));
      final rejected = await meal();
      mealStatus = 403;
      expect(await approve(rejected), TempTargetSendResult.failed);
      expect(
        await db.activityDao.finishActivityLogIfOpen(
          logId,
          startedAt,
          closedAt,
        ),
        isTrue,
      );
      now = closedAt.add(const Duration(minutes: 10));
      expect(
        await service.stopFinishedActivityTarget(),
        TempTargetSendResult.sent,
      );
      expect(posts.last['duration'], 0);
      expect(posts.last['date'], closedAt.millisecondsSinceEpoch);
      expect(posts, hasLength(3));
      expect(
        await service.stopFinishedActivityTarget(),
        TempTargetSendResult.ignored,
      );
    }),
  );

  test(
    'a nearby uncertain start still blocks cancellation until reconciled',
    () => withClock(Clock(() => now), () async {
      final logId = await activity(
        start: now.subtract(const Duration(minutes: 10)),
      );
      final ownedOffer = (await service.activityOffer(logId))!;
      expect(await approve(ownedOffer), TempTargetSendResult.sent);
      final startedAt = now.subtract(const Duration(minutes: 10));
      final closedAt = now.add(const Duration(minutes: 10));
      now = closedAt.add(const Duration(milliseconds: 500));
      final uncertain = await meal();
      mealStatus = 503;
      expect(await approve(uncertain), TempTargetSendResult.failed);
      expect(
        await db.activityDao.finishActivityLogIfOpen(
          logId,
          startedAt,
          closedAt,
        ),
        isTrue,
      );
      now = closedAt.add(const Duration(minutes: 10));
      expect(
        await service.stopFinishedActivityTarget(),
        TempTargetSendResult.ignored,
      );
      expect(posts, hasLength(2));
      expect(
        (await operations.get(uncertain.requestId!))!.status,
        TempTargetOperationStatus.unknownResult,
      );
    }),
  );
}
