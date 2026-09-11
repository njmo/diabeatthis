import '../../../../core/domain/model/bolus_wizard.dart';
import '../models/day_meal_review_entry.dart';

/// Only a unique meal and a unique wizard in the same absolute clock minute
/// qualify. No wider proximity search and no macro-based guesses.
class ReconcileDayMealReviewUseCase {
  final Future<List<DayMealReviewEntry>> Function(DateTime) build;
  final Future<void> Function(BolusWizard, int) linkAutomatically;

  const ReconcileDayMealReviewUseCase({
    required this.build,
    required this.linkAutomatically,
  });

  Future<List<DayMealReviewEntry>> call(DateTime date) async {
    final entries = await build(date);
    int minute(DateTime time) => time.millisecondsSinceEpoch ~/ 60000;
    final candidates = entries.where((entry) => entry.meal != null).toList();
    final allWizards = entries.expand((entry) => entry.wizards).toList();
    var attempted = false;
    for (final entry in entries.where(
      (entry) => entry.meal == null && !entry.automaticMatchingBlocked,
    )) {
      final wizard = entry.wizards.single;
      if (wizard.localId == null &&
          (wizard.nightscoutObjectId == null || wizard.remoteSource == null)) {
        continue;
      }
      final time = minute(wizard.createdAt);
      final meals = candidates
          .where((entry) => minute(entry.meal!.eatenAt) == time)
          .toList();
      if (meals.length != 1 ||
          meals.single.wizards.isNotEmpty ||
          allWizards.where((other) => minute(other.createdAt) == time).length !=
              1) {
        continue;
      }
      await linkAutomatically(wizard, meals.single.meal!.id);
      attempted = true;
    }
    return attempted ? build(date) : entries;
  }
}
