import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/provider/shared_prefs_provider.dart';

final pendingMealCompletionRequestsProvider =
    Provider<PendingMealCompletionRequests>(
      (ref) => PendingMealCompletionRequests(
        preferences: () => ref.read(sharedPrefsProvider.future),
      ),
    );

/// Durable notification intents shared by the notification, service and UI isolates.
class PendingMealCompletionRequests {
  static const keyPrefix = 'pending_meal_completion.';

  const PendingMealCompletionRequests({
    this.preferences = SharedPreferences.getInstance,
  });

  final Future<SharedPreferences> Function() preferences;

  Future<void> request(int mealId) async {
    final prefs = await preferences();
    await prefs.reload();
    final key = '$keyPrefix$mealId';
    if (prefs.containsKey(key)) return;
    if (!await prefs.setInt(key, clock.now().millisecondsSinceEpoch)) {
      throw StateError('Could not persist meal completion request');
    }
  }

  Future<Set<int>> pending() async {
    final prefs = await preferences();
    await prefs.reload();
    return prefs
        .getKeys()
        .where((key) => key.startsWith(keyPrefix))
        .map((key) => int.tryParse(key.substring(keyPrefix.length)))
        .whereType<int>()
        .toSet();
  }

  Future<void> acknowledge(int mealId) async {
    final prefs = await preferences();
    await prefs.reload();
    if (!await prefs.remove('$keyPrefix$mealId')) {
      throw StateError('Could not acknowledge meal completion request');
    }
  }
}
