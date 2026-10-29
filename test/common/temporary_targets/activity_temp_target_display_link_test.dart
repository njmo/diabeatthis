import 'package:diabeatthis/common/temporary_targets/is_activity_temp_target_linked.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 29, 16);
  TemporaryTarget target(
    int value, {
    DateTime? start,
    int duration = 90,
    bool valid = true,
  }) => TemporaryTarget(
    nightscoutId: 'external-target',
    createdAt: start ?? now,
    durationInMiliseconds: Duration(minutes: duration).inMilliseconds,
    duration: duration,
    targetBottom: value,
    targetTop: value,
    isValid: valid,
  );

  for (final value in [90, 139, 140, 160, 180]) {
    test(
      'visible activity links an active $value target exactly from the 140 threshold',
      () {
        expect(
          isActivityTempTargetLinked(
            activityVisible: true,
            target: target(value),
            now: now,
          ),
          value >= 140,
        );
      },
    );
  }

  test(
    'an active high target stays independent while the activity is hidden',
    () {
      expect(
        isActivityTempTargetLinked(
          activityVisible: false,
          target: target(160),
          now: now,
        ),
        isFalse,
      );
    },
  );

  test('expired, future, invalid and zero-duration targets never attach', () {
    for (final candidate in [
      target(160, start: now.subtract(const Duration(minutes: 90))),
      target(160, start: now.add(const Duration(minutes: 1))),
      target(160, valid: false),
      target(160, duration: 0),
    ]) {
      expect(
        isActivityTempTargetLinked(
          activityVisible: true,
          target: candidate,
          now: now,
        ),
        isFalse,
      );
    }
  });
}
