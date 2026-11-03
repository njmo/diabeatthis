import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/domain/model/temporary_target.dart';
import 'temp_target_identity.dart';

/// Local display associations never grant ownership or authorize remote writes.
class MealTargetLinks {
  const MealTargetLinks(this.preferences);

  final SharedPreferences preferences;
  static const storageKey = 'meal_target_display_links_v1';

  Map<String, dynamic> _read() {
    final stored = preferences.getString(storageKey);
    if (stored == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(stored) as Map);
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  int? mealId(String source, TemporaryTarget target) {
    final value = _read()[TempTargetIdentity.key(source, target)];
    return value is int ? value : null;
  }

  Future<void> attach(String source, TemporaryTarget target, int mealId) async {
    final links = _read();
    links[TempTargetIdentity.key(source, target)] = mealId;
    while (links.length > 200) {
      links.remove(links.keys.first);
    }
    if (!await preferences.setString(storageKey, jsonEncode(links))) {
      throw StateError('Could not save meal target association');
    }
  }
}
