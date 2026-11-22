import 'package:clock/clock.dart';

import '../../../core/domain/model/device_status.dart';
import '../../../core/domain/model/glucose.dart';
import '../../../core/domain/model/temporary_target.dart';
import '../../../core/domain/model/treatment_base.dart';
import '../../history/nightscout_history_repositories.dart';

class CaregiverMealContextHistory {
  const CaregiverMealContextHistory({
    required this.asOf,
    this.syncedAt,
    required this.glucose,
    required this.devices,
    required this.treatments,
  });
  final DateTime asOf;
  final DateTime? syncedAt;
  final List<Glucose> glucose;
  final List<DeviceStatus> devices;
  final List<Treatment> treatments;

  DateTime get start => asOf.subtract(const Duration(minutes: 30));
  DateTime get end => asOf.add(const Duration(minutes: 5));

  List<Glucose> get readings =>
      glucose
          .where(
            (reading) =>
                reading.type == GlucoseType.cgm &&
                reading.sgv > 0 &&
                !reading.date.isAfter(asOf) &&
                !reading.date.isBefore(start),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  List<DeviceStatus> get statuses =>
      devices
          .where(
            (status) =>
                !status.date.isAfter(asOf) && !status.date.isBefore(start),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  static Future<CaregiverMealContextHistory> load(
    NightscoutHistoryRepositories history, {
    TemporaryTarget? cachedTarget,
    Duration? seriesTimeout,
  }) async {
    final now = clock.now();
    final start = now.subtract(const Duration(minutes: 30));
    Future<List<T>?> readSeries<T>(Future<List<T>> request) async {
      if (seriesTimeout == null) return request;
      try {
        return await request.timeout(seriesTimeout);
      } catch (_) {
        return null;
      }
    }

    final glucose = readSeries(history.glucose.fetchGlucoseBetween(start, now));
    final devices = readSeries(
      history.deviceStatuses.fetchDeviceStatusBetween(start, now),
    );
    final treatments = readSeries(
      history.treatments.fetchTreatmentsBetween(
        now.subtract(const Duration(hours: 24)),
        now.add(const Duration(hours: 4)),
      ),
    );
    final all = await Future.wait<Object?>([glucose, devices, treatments]);
    final entries = List<Treatment>.of(all[2] as List<Treatment>? ?? const []);
    if (cachedTarget != null &&
        !entries.whereType<TemporaryTarget>().any(
          (target) => target.createdAt == cachedTarget.createdAt,
        )) {
      entries.add(cachedTarget);
    }
    return CaregiverMealContextHistory(
      asOf: now,
      syncedAt: all.any((series) => series != null) ? clock.now() : null,
      glucose: all[0] as List<Glucose>? ?? const [],
      devices: all[1] as List<DeviceStatus>? ?? const [],
      treatments: entries,
    );
  }

  List<MealDecisionTargetWindow> get targets {
    final ordered =
        treatments
            .whereType<TemporaryTarget>()
            .where((target) => target.isValid)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [
          for (var i = 0; i < ordered.length; i++)
            if (ordered[i].duration > 0 &&
                ordered[i].targetBottom > 0 &&
                ordered[i].targetTop >= ordered[i].targetBottom)
              MealDecisionTargetWindow(
                ordered[i],
                i + 1 < ordered.length &&
                        ordered[i + 1].createdAt.isBefore(
                          ordered[i].createdAt.add(
                            Duration(minutes: ordered[i].duration),
                          ),
                        )
                    ? ordered[i + 1].createdAt
                    : ordered[i].createdAt.add(
                        Duration(minutes: ordered[i].duration),
                      ),
              ),
        ]
        .where(
          (window) =>
              window.end.isAfter(window.target.createdAt) &&
              window.end.isAfter(asOf.subtract(const Duration(minutes: 30))) &&
              !window.target.createdAt.isAfter(asOf),
        )
        .toList();
  }
}

class MealDecisionTargetWindow {
  const MealDecisionTargetWindow(this.target, this.end);
  final TemporaryTarget target;
  final DateTime end;
}
