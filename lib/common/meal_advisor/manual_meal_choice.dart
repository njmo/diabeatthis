import 'package:shared_preferences/shared_preferences.dart';

String _key(int mealId) => 'meal-manual:$mealId';

bool usesManualMealChoice(
  SharedPreferences prefs,
  int mealId,
  int? plannedAtMs,
) => prefs.getInt(_key(mealId)) == (plannedAtMs ?? -1);

Future<bool> saveManualMealChoice(
  SharedPreferences prefs,
  int mealId,
  int? plannedAtMs,
) => prefs.setInt(_key(mealId), plannedAtMs ?? -1);
