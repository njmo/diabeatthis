import 'package:clock/clock.dart';
import 'package:diabeatthis/common/temporary_targets/is_activity_temp_target_linked.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' hide TemporaryTarget;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseImpl db;
  late TempTargetService service;
  late SharedPreferences prefs;
  final now = DateTime(2026, 10, 29, 16);
  final start = DateTime(2026, 10, 29, 17);
  late int logId;

  TemporaryTarget target({
    int bottom = 140,
    int top = 140,
    DateTime? createdAt,
    int minutes = 120,
    bool isValid = true,
  }) => TemporaryTarget(
    nightscoutId: 'external-target',
    createdAt: createdAt ?? now,
    durationInMiliseconds: minutes * Duration.millisecondsPerMinute,
    duration: minutes,
    targetBottom: bottom,
    targetTop: top,
    isValid: isValid,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: 'https://example.com',
      nightscoutTokenKey: 'test-token',
      nightscoutTempTargetsEnabledKey: true,
    });
    prefs = await SharedPreferences.getInstance();
    db = DatabaseImpl(NativeDatabase.memory());
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
    logId = await db
        .into(db.activityLog)
        .insert(
          ActivityLogCompanion.insert(
            activityId: activityId,
            startedAt: start.millisecondsSinceEpoch,
          ),
        );
    service = TempTargetService(
      preferences: () async => prefs,
      database: () => db,
      writer: NightscoutTempTargetWriter(
        client: MockClient((request) async {
          throw StateError(
            'Recognizing existing coverage must not send a request',
          );
        }),
      ),
    );
  });
  tearDown(() => db.close());

  for (final value in [140, 160, 180]) {
    test(
      'an external $value target covering the session agrees with the dashboard classification',
      () => withClock(Clock.fixed(now), () async {
        final active = target(bottom: value, top: value);
        expect(
          isActivityTempTargetLinked(
            activityVisible: true,
            target: active,
            now: now,
          ),
          isTrue,
        );
        expect(
          await service.activityOffer(logId, activeTarget: active),
          isNull,
        );
        expect(prefs.containsKey(nightscoutOwnedTempTargetKey), isFalse);
      }),
    );
  }

  test(
    'a target range with an upper bound of 140 follows the same shared acceptance rule',
    () => withClock(Clock.fixed(now), () async {
      final active = target(bottom: 130);
      expect(isActivityTempTarget(active), isTrue);
      expect(await service.activityOffer(logId, activeTarget: active), isNull);
    }),
  );

  test(
    'a target below 140 still needs a confirmed activity offer',
    () => withClock(Clock.fixed(now), () async {
      final active = target(bottom: 139, top: 139);
      expect(isActivityTempTarget(active), isFalse);
      final offer = await service.activityOffer(logId, activeTarget: active);
      expect(offer!.target, 140);
      expect(offer.durationMinutes, 120);
    }),
  );

  for (final state in ['invalid', 'future', 'expired']) {
    test(
      'an $state high target does not suppress a new offer',
      () => withClock(Clock.fixed(now), () async {
        final active = target(
          top: 160,
          bottom: 160,
          isValid: state != 'invalid',
          createdAt: switch (state) {
            'future' => now.add(const Duration(minutes: 1)),
            'expired' => now.subtract(const Duration(hours: 2)),
            _ => now,
          },
        );
        final offer = await service.activityOffer(logId, activeTarget: active);
        expect(offer, isNotNull);
        expect(offer!.target, 140);
      }),
    );
  }

  test(
    'high target coverage ending early asks for renewal near its end',
    () =>
        withClock(Clock.fixed(now.add(const Duration(minutes: 20))), () async {
          final offer = await service.activityOffer(
            logId,
            activeTarget: target(top: 160, bottom: 160, minutes: 30),
          );
          expect(offer!.target, 140);
          expect(offer.renewal, isTrue);
          expect(offer.durationMinutes, 100);
          expect(prefs.containsKey(nightscoutOwnedTempTargetKey), isFalse);
        }),
  );
}
