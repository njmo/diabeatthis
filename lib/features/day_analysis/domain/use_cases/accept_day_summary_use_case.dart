import '../models/accepted_day_summary.dart';
import '../models/day_summary_snapshot.dart';

class StaleDaySummary implements Exception {
  const StaleDaySummary();
}

class AcceptDaySummaryUseCase {
  final Future<DaySummarySnapshot> Function() loadCurrent;
  final Future<void> Function(AcceptedDaySummary) save;
  final DateTime Function() now;
  const AcceptDaySummaryUseCase({
    required this.loadCurrent,
    required this.save,
    required this.now,
  });

  static bool isAvailable(DateTime date, DateTime now) {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final day = DateTime(date.year, date.month, date.day);
    return day.isBefore(today);
  }

  Future<AcceptedDaySummary> call(
    DaySummarySnapshot preview, {
    required Set<int> skippedRecords,
    required bool acknowledgeLimitations,
  }) async {
    final date = DateTime.parse(preview.dayKey);
    if (!isAvailable(date, now())) {
      throw StateError('Day review is not available yet');
    }
    if (!preview.asOf.isAtSameMomentAs(
      DateTime(date.year, date.month, date.day + 1),
    )) {
      throw StateError('A completed day observation window is required');
    }
    if (preview.limitations.isNotEmpty && !acknowledgeLimitations) {
      throw StateError('Missing history must be acknowledged');
    }
    for (var i = 0; i < preview.review.length; i++) {
      if (preview.review[i].resolution == DaySummaryResolution.unresolved &&
          !skippedRecords.contains(i)) {
        throw StateError('Unresolved records must be reviewed');
      }
    }
    final current = await loadCurrent();
    if (current.encode() != preview.encode()) throw const StaleDaySummary();
    final acceptedAt = now();
    if (preview.asOf.isAfter(acceptedAt)) {
      throw StateError('Future observation window');
    }
    final accepted = AcceptedDaySummary(
      acceptedAt: acceptedAt,
      snapshot: preview,
    );
    await save(accepted);
    return accepted;
  }
}
