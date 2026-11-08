import '../../../core/domain/model/device_status.dart';
import '../../../core/domain/model/glucose.dart';
import '../../../core/domain/model/temporary_target.dart';
import '../../../core/domain/model/treatment_base.dart';

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
