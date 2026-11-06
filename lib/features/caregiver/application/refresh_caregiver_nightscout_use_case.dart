import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import '../../../core/domain/model/device_status.dart';
import '../../../core/domain/model/glucose.dart';
import '../../../core/domain/model/temporary_target.dart';
import '../data/caregiver_nightscout_snapshot.dart';

final refreshCaregiverNightscoutProvider = Provider(
  (ref) => RefreshCaregiverNightscoutUseCase(ref),
);

class RefreshCaregiverNightscoutUseCase {
  const RefreshCaregiverNightscoutUseCase(this.ref);
  final Ref ref;
  Future<CaregiverNightscoutSnapshot> call() async {
    final repository = await ref.read(nightscoutRepositoryProvider.future);
    List<Glucose>? glucose;
    DeviceStatus? device;
    TemporaryTarget? target;
    var targetFetched = false;
    var deviceFetched = false;
    var failures = false;
    await Future.wait([
      () async {
        try {
          glucose =
              (await repository
                      .fetchLastGlucoseWithLimit(10)
                      .timeout(const Duration(seconds: 15)))
                  .where(
                    (reading) =>
                        reading.type == GlucoseType.cgm && reading.sgv > 0,
                  )
                  .toList();
        } catch (_) {
          failures = true;
        }
      }(),
      () async {
        try {
          device = await repository.fetchLastDeviceStatus().timeout(
            const Duration(seconds: 15),
          );
          deviceFetched = true;
        } on StateError catch (error) {
          if (error.message == 'No element') {
            deviceFetched = true;
          } else {
            failures = true;
          }
        } catch (_) {
          failures = true;
        }
      }(),
      () async {
        try {
          target = await repository.fetchLastTemporaryTarget().timeout(
            const Duration(seconds: 15),
          );
          targetFetched = true;
        } on StateError catch (error) {
          if (error.message == 'No element') {
            targetFetched = true;
          } else {
            failures = true;
          }
        } catch (_) {
          failures = true;
        }
      }(),
    ]);
    return CaregiverNightscoutSnapshot(
      glucose: glucose,
      deviceStatus: device,
      deviceFetched: deviceFetched,
      temporaryTarget: target,
      targetFetched: targetFetched,
      hasFailures: failures,
    );
  }
}
