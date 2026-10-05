import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../models/aaps_carbs_request_signal.dart';

class EvaluateAapsCarbsRequestUseCase {
  static const maximumAge = Duration(minutes: 10);

  const EvaluateAapsCarbsRequestUseCase();

  AapsCarbsRequestSignal call({
    required DeviceStatus? status,
    required Iterable<Glucose> glucose,
    required DateTime now,
  }) {
    if (!_isFresh(status?.suggestedAt ?? status?.date, now) ||
        status?.hasCarbsReq != true) {
      return const AapsCarbsRequestSignal.unavailable();
    }

    final carbsReq = status!.carbsReq;
    if (!carbsReq.isFinite || carbsReq < 0) {
      return const AapsCarbsRequestSignal.unavailable();
    }
    if (carbsReq == 0) {
      return AapsCarbsRequestSignal.withdrawn(status);
    }

    final hasFreshCgm = glucose.any(
      (reading) =>
          reading.type == GlucoseType.cgm &&
          reading.sgv > 0 &&
          _isFresh(reading.date, now),
    );
    return hasFreshCgm
        ? AapsCarbsRequestSignal.positive(status)
        : const AapsCarbsRequestSignal.unavailable();
  }

  bool _isFresh(DateTime? at, DateTime now) {
    if (at == null || at.isAfter(now)) return false;
    return now.difference(at) < maximumAge;
  }
}
