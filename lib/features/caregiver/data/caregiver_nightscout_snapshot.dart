import 'package:clock/clock.dart';

import '../../../core/domain/model/device_status.dart';
import '../../../core/domain/model/glucose.dart';
import '../../../core/domain/model/temporary_target.dart';

class CaregiverNightscoutSnapshot {
  const CaregiverNightscoutSnapshot({
    this.glucose,
    this.deviceStatus,
    this.temporaryTarget,
    required this.targetFetched,
    required this.hasFailures,
    this.deviceFetched = false,
  });
  final List<Glucose>? glucose;
  final DeviceStatus? deviceStatus;
  final bool deviceFetched;
  final TemporaryTarget? temporaryTarget;
  final bool targetFetched;
  final bool hasFailures;
  List<Glucose> get readings =>
      (glucose ?? const <Glucose>[])
          .where(
            (reading) =>
                reading.type == GlucoseType.cgm &&
                reading.sgv > 0 &&
                !reading.date.isAfter(
                  clock.now().add(const Duration(minutes: 2)),
                ),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  Glucose? get latestGlucose => readings.firstOrNull;
  bool get hasData =>
      glucose != null || deviceStatus != null || deviceFetched || targetFetched;
}
