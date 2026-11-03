import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const source = 'https://example.com';
  final now = DateTime.utc(2026, 11, 3, 8);
  final target = TemporaryTarget(
    nightscoutId: 'displayed',
    createdAt: now.subtract(const Duration(minutes: 10)),
    durationInMiliseconds: 3600000,
    duration: 60,
    targetBottom: 110,
    targetTop: 110,
  );
  late SharedPreferences prefs;
  late DatabaseImpl db;
  late Map<String, dynamic> remote;
  late TempTargetService service;
  int posts = 0;
  int reads = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: source,
      nightscoutTokenKey: 'test-token',
      nightscoutTempTargetsEnabledKey: true,
    });
    prefs = await SharedPreferences.getInstance();
    db = DatabaseImpl(NativeDatabase.memory());
    posts = 0;
    reads = 0;
    remote = {
      '_id': target.nightscoutId,
      'eventType': 'Temporary Target',
      'enteredBy': 'AAPS',
      'created_at': target.createdAt.toIso8601String(),
      'duration': 60,
      'targetBottom': 110,
      'targetTop': 110,
    };
    service = TempTargetService(
      preferences: () async => prefs,
      database: () => db,
      writer: NightscoutTempTargetWriter(client: MockClient((request) async {
        if (request.method == 'GET') {
          reads++;
          return http.Response(jsonEncode([remote]), 200);
        }
        posts++;
        expect((jsonDecode(request.body) as Map)['duration'], 0);
        return http.Response('', 201);
      })),
    );
  });
  tearDown(() => db.close());

  test('disabled control and changed source never issue a remote request', () async {
    await withClock(Clock.fixed(now), () async {
      await prefs.setBool(nightscoutTempTargetsEnabledKey, false);
      expect(await service.stopDisplayedTarget(target, source: source), TempTargetSendResult.ignored);
      await prefs.setBool(nightscoutTempTargetsEnabledKey, true);
      expect(await service.stopDisplayedTarget(target, source: 'other'), TempTargetSendResult.ignored);
      expect(reads, 0);
      expect(posts, 0);
    });
  });

  test('a replacement or edited remote target cannot be stopped by a stale card', () async {
    await withClock(Clock.fixed(now), () async {
      remote['_id'] = 'replacement';
      expect(await service.stopDisplayedTarget(target, source: source), TempTargetSendResult.expired);
      remote['_id'] = target.nightscoutId;
      remote['targetTop'] = 140;
      expect(await service.stopDisplayedTarget(target, source: source), TempTargetSendResult.expired);
      expect(posts, 0);
    });
  });

  test('explicit enabled stop verifies the AAPS target and records only one send', () async {
    await withClock(Clock.fixed(now), () async {
      expect(await service.stopDisplayedTarget(target, source: source), TempTargetSendResult.sent);
      expect(await service.stopDisplayedTarget(target, source: source), TempTargetSendResult.ignored);
      expect(posts, 1);
    });
  });
}
