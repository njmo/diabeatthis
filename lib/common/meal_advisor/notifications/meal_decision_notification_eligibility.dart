import 'package:shared_preferences/shared_preferences.dart';

/// A single value prevents an old account's eligibility being used by a new one.
class MealDecisionNotificationEligibility {
  static const key = 'meal_decision_notification_eligibility';
  final SharedPreferencesAsync storage = SharedPreferencesAsync();

  Future<void> set(String uid, bool enabled) =>
      storage.setString(key, '$uid:${enabled ? 1 : 0}');
  Future<bool> allows(String? uid) async =>
      uid != null && await storage.getString(key) == '$uid:1';
}
