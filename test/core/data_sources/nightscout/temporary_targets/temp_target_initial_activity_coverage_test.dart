import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseImpl db;
  late TempTargetService service;
  late DateTime now;
  late DateTime start;
  late List<Map<String, dynamic>> posts;

  setUp(() async {
    now = DateTime(2026, 10, 29, 17);
    start = DateTime(2026, 10, 29, 18);
    posts = [];
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: 'https://example.com',
      nightscoutTokenKey: 'token',
      nightscoutTempTargetsEnabledKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    db = DatabaseImpl(NativeDatabase.memory());
    service = TempTargetService(
      preferences: () async => prefs,
      database: () => db,
      writer: NightscoutTempTargetWriter(
        client: MockClient((request) async {
          posts.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('', 201);
        }),
      ),
    );
    final activityId = await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'Walk',
            percentagePre: 0,
            percentagePost: 0,
          ),
        );
    await db
        .into(db.activityLog)
        .insert(
          ActivityLogCompanion.insert(
            activityId: activityId,
            startedAt: start.millisecondsSinceEpoch,
          ),
        );
  });
  tearDown(() => db.close());

  test(
    'initial manual target ends thirty minutes after start even with late consent',
    () => withClock(Clock(() => now), () async {
      final offer = (await service.activityOffer(1))!;
      expect(offer.durationMinutes, 90);
      expect(offer.renewal, isFalse);
      now = now.add(const Duration(minutes: 15));
      expect(
        await service.respond(
          requestId: offer.requestId!,
          targetType: offer.targetType,
          entityId: 1,
          approved: true,
        ),
        TempTargetSendResult.sent,
      );
      expect(posts.single['duration'], 75);
      final end = DateTime.parse(
        posts.single['created_at'] as String,
      ).add(Duration(minutes: posts.single['duration'] as int));
      expect(end, start.add(const Duration(minutes: 30)).toUtc());
      now = start.add(const Duration(minutes: 29));
      expect(await service.activityOffer(1), isNull);
      now = start.add(const Duration(minutes: 30));
      final renewal = (await service.activityOffer(1))!;
      expect(renewal.renewal, isTrue);
      expect(renewal.durationMinutes, 90);
      expect(posts, hasLength(1));
    }),
  );

  test(
    'planning close to the start does not add a fixed ninety minutes',
    () => withClock(Clock(() => now), () async {
      now = start.subtract(const Duration(minutes: 10));
      final offer = (await service.activityOffer(1))!;
      expect(offer.durationMinutes, 40);
      expect(posts, isEmpty);
    }),
  );

  test(
    'starting monitoring after the initial period asks about continuing activity',
    () => withClock(Clock(() => now), () async {
      now = start.add(const Duration(minutes: 40));
      final offer = (await service.activityOffer(1))!;
      expect(offer.renewal, isTrue);
      expect(offer.durationMinutes, 90);
      expect(posts, isEmpty);
    }),
  );

  test(
    'initial consent is invalid once the first thirty minutes of activity have passed',
    () => withClock(Clock(() => now), () async {
      final offer = (await service.activityOffer(1))!;
      now = start.add(const Duration(minutes: 31));
      expect(
        await service.respond(
          requestId: offer.requestId!,
          targetType: offer.targetType,
          entityId: 1,
          approved: true,
        ),
        TempTargetSendResult.expired,
      );
      expect(posts, isEmpty);
      expect(await service.activityOffer(1), isNull);
    }),
  );
}
