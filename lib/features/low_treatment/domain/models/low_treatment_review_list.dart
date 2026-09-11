import '../../../../core/domain/model/treat.dart';
import 'low_treatment_review_entry.dart';
import 'recorded_low_treatment.dart';

/// A single consumption appears once, with all independently reversible links.
class LowTreatmentReviewList {
  final List<LowTreatmentReviewEntry> visible;
  final List<LowTreatmentReviewEntry> dismissed;
  final List<RecordedLowTreatment> recorded;
  final Map<int, List<Treat>> linkedEvents;
  final int pendingCount;

  LowTreatmentReviewList(Iterable<LowTreatmentReviewEntry> entries)
    : this._build(entries.toList());

  LowTreatmentReviewList._build(List<LowTreatmentReviewEntry> entries)
    : visible = List.unmodifiable(_visible(entries)),
      dismissed = List.unmodifiable(entries.where((entry) => entry.dismissed)),
      recorded = List.unmodifiable(
        {
          for (final entry in entries)
            if (entry.recorded != null) entry.recorded!.mealId: entry.recorded!,
        }.values,
      ),
      linkedEvents = _links(entries),
      pendingCount = entries.where((entry) => entry.isPending).length;

  static Iterable<LowTreatmentReviewEntry> _visible(
    List<LowTreatmentReviewEntry> entries,
  ) sync* {
    final seen = <int>{};
    for (final entry in entries) {
      if (entry.dismissed) continue;
      final id = entry.recorded?.mealId;
      if (id == null || seen.add(id)) yield entry;
    }
  }

  static Map<int, List<Treat>> _links(List<LowTreatmentReviewEntry> entries) {
    final links = <int, List<Treat>>{};
    for (final entry in entries) {
      if (entry.recorded != null && entry.event != null) {
        links.putIfAbsent(entry.recorded!.mealId, () => []).add(entry.event!);
      }
    }
    return Map.unmodifiable(
      links.map((id, events) => MapEntry(id, List<Treat>.unmodifiable(events))),
    );
  }
}
