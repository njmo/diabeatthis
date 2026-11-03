import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../domain/models/meal_activity_windows.dart';

const mealActivityPastMinutesKey = 'meal_advisor_activity_past_minutes';
const mealActivityFutureMinutesKey = 'meal_advisor_activity_future_minutes';

final mealActivityWindowsProvider = FutureProvider<MealActivityWindows>((
  ref,
) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  final windows = MealActivityWindows(
    pastMinutes: prefs.getInt(mealActivityPastMinutesKey) ?? 120,
    futureMinutes: prefs.getInt(mealActivityFutureMinutesKey) ?? 60,
  );
  return windows.isValid ? windows : const MealActivityWindows();
});

final mealActivityWindowsControllerProvider = Provider(
  (ref) => MealActivityWindowsController(ref),
);

class MealActivityWindowsController {
  const MealActivityWindowsController(this.ref);
  final Ref ref;

  Future<void> savePastMinutes(int minutes) =>
      _save(mealActivityPastMinutesKey, minutes);

  Future<void> saveFutureMinutes(int minutes) =>
      _save(mealActivityFutureMinutesKey, minutes);

  Future<void> _save(String key, int minutes) async {
    if (minutes < 0 || minutes > 1440) {
      throw ArgumentError('Invalid activity window');
    }
    final prefs = await ref.read(sharedPrefsProvider.future);
    if (!await prefs.setInt(key, minutes)) {
      throw StateError('Could not save activity window');
    }
    ref.invalidate(mealActivityWindowsProvider);
  }
}
