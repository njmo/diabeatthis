import 'dart:math' as math;

import '../../core/domain/model/device_status.dart';
import 'history_coverage_gap.dart';

/// Reconstruction from pump snapshots, not a pump delivery ledger.
/// Totals and profile differences refer only to covered intervals.
class InsulinBasalSummary {
  final double units;
  final double profileUnits;
  final double addedUnits;
  final double reducedUnits;
  final Duration coveredDuration;
  final Duration duration;
  final List<HistoryCoverageGap> gaps;

  InsulinBasalSummary({
    required this.units,
    required this.profileUnits,
    required this.addedUnits,
    required this.reducedUnits,
    required this.coveredDuration,
    required this.duration,
    required List<HistoryCoverageGap> gaps,
  }) : gaps = List.unmodifiable(gaps);

  double get coverage => duration.inMicroseconds <= 0
      ? 0
      : coveredDuration.inMicroseconds / duration.inMicroseconds;

  /// A snapshot is carried for at most ten minutes. Repeated reports with the
  /// same pump clock do not extend coverage. Future uploads are excluded.
  static const maxSnapshotAge = Duration(minutes: 10);

  factory InsulinBasalSummary.calculate(
    List<DeviceStatus> records,
    DateTime start,
    DateTime end,
  ) {
    if (end.isBefore(start)) throw ArgumentError('End precedes start');
    final snapshots = <DateTime, DeviceStatus>{};
    final ordered = records.where((s) => !s.date.isAfter(end)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final status in ordered) {
      final at = status.basalObservedAt;
      if (at == null ||
          at.isAfter(end) ||
          at.isAfter(status.date.add(const Duration(minutes: 1)))) {
        continue;
      }
      snapshots[at] = status;
    }
    final times = snapshots.keys.toList()..sort();
    var units = 0.0;
    var profileUnits = 0.0;
    var added = 0.0;
    var reduced = 0.0;
    var covered = 0;
    var coveredUntil = start;
    final gaps = <HistoryCoverageGap>[];
    void accumulate(DateTime from, DateTime to, double rate, double profile) {
      if (!to.isAfter(from)) return;
      if (from.isAfter(coveredUntil)) {
        gaps.add(HistoryCoverageGap(start: coveredUntil, end: from));
      }
      coveredUntil = to;
      final micros = to.difference(from).inMicroseconds;
      final hours = micros / Duration.microsecondsPerHour;
      units += rate * hours;
      profileUnits += profile * hours;
      added += math.max(0, rate - profile) * hours;
      reduced += math.max(0, profile - rate) * hours;
      covered += micros;
    }

    for (var i = 0; i < times.length; i++) {
      final at = times[i];
      final status = snapshots[at]!;
      final from = at.isBefore(start) ? start : at;
      var to = at.add(maxSnapshotAge);
      if (i + 1 < times.length && times[i + 1].isBefore(to)) to = times[i + 1];
      if (end.isBefore(to)) to = end;
      if (!to.isAfter(from)) continue;
      final profile = status.baseBasalRate;
      if (!profile.isFinite ||
          profile < 0 ||
          status.tempBasalRemainingMinutes < 0) {
        continue;
      }
      if (status.tempBasalRemainingMinutes == 0) {
        // A start without remaining time is ambiguous; do not assume profile.
        if (status.tempBasalStartedAt != null ||
            status.tempBasalAbsoluteRate != null) {
          continue;
        }
        accumulate(from, to, profile, profile);
        continue;
      }
      final rate = resolveTempRate(status);
      final expiry = at.add(
        Duration(minutes: status.tempBasalRemainingMinutes),
      );
      final tempEnd = expiry.isBefore(to) ? expiry : to;
      if (rate != null) accumulate(from, tempEnd, rate, profile);
      // Stop at expiry: without a new snapshot the resumed profile is unknown.
    }
    if (coveredUntil.isBefore(end)) {
      gaps.add(HistoryCoverageGap(start: coveredUntil, end: end));
    }
    return InsulinBasalSummary(
      units: units,
      profileUnits: profileUnits,
      addedUnits: added,
      reducedUnits: reduced,
      coveredDuration: Duration(microseconds: covered),
      duration: end.difference(start),
      gaps: gaps,
    );
  }

  static double? resolveTempRate(DeviceStatus status) {
    final explicit = status.tempBasalAbsoluteRate;
    if (explicit != null) {
      return explicit.isFinite && explicit >= 0 ? explicit : null;
    }
    // AAPS PumpStatusProviderImpl exports the temporary basal's start and
    // remaining time, but putIfThereIsValue omits a Double equal to zero.
    // Those active-temp markers distinguish zero from an incomplete snapshot.
    // enacted is optional and reports commands, not every ongoing basal state.
    // Verified against AndroidAPS 3.4.2.2, JSONObjectExt.kt and
    // implementation/pump/PumpStatusProviderImpl.kt.
    if (status.tempBasalRemainingMinutes > 0 &&
        status.tempBasalStartedAt?.trim().isNotEmpty == true) {
      return 0;
    }
    return null;
  }
}
