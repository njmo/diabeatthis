import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/device_status_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/device_status_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/device_status_mapper.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/check_meal_advisor_device_status_use_case.dart';
import 'package:diabeatthis/foreground/event/external/local_device_status/local_device_status_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/device_status_factory.dart';

void main() {
  final now = DateTime(2026, 9, 9, 12);
  final status = testDeviceStatus(
    date: now,
    iob: 0,
    cob: 0,
    tick: '0',
    bg: 120,
  );
  const check = CheckMealAdvisorDeviceStatusUseCase();

  test('zero is valid, missing is not; negative net IOB remains valid', () {
    withClock(Clock.fixed(now), () {
      expect(check(status), MealAdviceEligibility.available);
      expect(check(status.copyWith(iob: -1)), MealAdviceEligibility.available);
      expect(
        check(status.copyWith(hasIob: false)),
        MealAdviceEligibility.incompleteDeviceStatus,
      );
      expect(
        check(status.copyWith(hasCob: false)),
        MealAdviceEligibility.incompleteDeviceStatus,
      );
      expect(check(null), MealAdviceEligibility.missingDeviceStatus);
      for (final invalid in [
        status.copyWith(iob: double.nan),
        status.copyWith(cob: double.infinity),
        status.copyWith(cob: -1),
        status.copyWith(bg: 0),
      ]) {
        expect(check(invalid), MealAdviceEligibility.invalidDeviceStatus);
      }
    });
  });
  test(
    'status is usable strictly below six minutes and cannot be from future',
    () {
      withClock(Clock.fixed(now), () {
        expect(
          check(
            status.copyWith(date: now.subtract(const Duration(seconds: 359))),
          ),
          MealAdviceEligibility.available,
        );
        expect(
          check(
            status.copyWith(date: now.subtract(const Duration(minutes: 6))),
          ),
          MealAdviceEligibility.staleDeviceStatus,
        );
        expect(
          check(status.copyWith(date: now.add(const Duration(seconds: 1)))),
          MealAdviceEligibility.staleDeviceStatus,
        );
      });
    },
  );
  test(
    'Nightscout, native AAPS and synchronization preserve missing vs zero',
    () {
      for (final present in [false, true]) {
        final dto = DeviceStatusDto(
          createdAt: now.toIso8601String(),
          openaps: {
            'suggested': {
              'bg': 120,
              if (present) 'IOB': 0,
              if (present) 'COB': 0,
            },
          },
        );
        final mapped = dto.toDomain();
        final synchronized = DeviceStatus.fromJson(mapped.toJson());
        final native = LocalDeviceStatusEvent.fromJson(
          LocalDeviceStatusEvent(data: mapped).toJson(),
        ).data;
        for (final result in [mapped, synchronized, native]) {
          expect(result.hasIob, present);
          expect(result.hasCob, present);
          expect(result.iob, 0);
          expect(result.cob, 0);
        }
      }
    },
  );
  test(
    'Drift round trip preserves absent values without a schema migration',
    () async {
      final db = drift.DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      for (final present in [false, true]) {
        await db.localMirrorDao.upsertDeviceStatus(
          status.copyWith(hasIob: present, hasCob: present).toCompanion(),
        );
        final row = await db.select(db.deviceStatus).getSingle();
        expect(row.iob, present ? 0 : null);
        expect(row.cob, present ? 0 : null);
        expect(row.toDomain().hasIob, present);
        expect(row.toDomain().hasCob, present);
      }
    },
  );
}
