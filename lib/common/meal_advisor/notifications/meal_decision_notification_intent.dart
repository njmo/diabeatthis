import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const mealDecisionNotificationType = 'meal_decision';
const mealDecisionNotificationActions = {
  'open',
  'claim',
  'delegate',
  'decline',
};

class MealDecisionNotificationIntent {
  const MealDecisionNotificationIntent(this.requestId, this.action);
  final String requestId;
  final String action;

  static MealDecisionNotificationIntent? parse(
    String? payload,
    String? action,
  ) {
    try {
      final value = jsonDecode(payload ?? '') as Map<String, dynamic>;
      final id = value['requestId'];
      final resolvedAction = action == null || action.isEmpty ? 'open' : action;
      if (value['type'] != mealDecisionNotificationType ||
          id is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ||
          !mealDecisionNotificationActions.contains(resolvedAction)) {
        return null;
      }
      return MealDecisionNotificationIntent(id, resolvedAction);
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode({
    'type': mealDecisionNotificationType,
    'requestId': requestId,
    'action': action,
  });
}

/// Stores interaction before navigation is ready, including a terminated-app launch.
class MealDecisionNotificationIntentStore {
  static const key = 'pending_meal_decision_notification_intents';
  static final StreamController<void> changes =
      StreamController<void>.broadcast();
  final SharedPreferencesAsync preferences = SharedPreferencesAsync();

  String storageKey(MealDecisionNotificationIntent intent) =>
      '$key:${intent.requestId}:${intent.action}';

  Future<List<MealDecisionNotificationIntent>> read() async {
    final records = <({MealDecisionNotificationIntent intent, int at})>[];
    for (final itemKey in await preferences.getKeys()) {
      if (!itemKey.startsWith('$key:')) continue;
      try {
        final value = await preferences.getString(itemKey);
        final json = jsonDecode(value ?? '') as Map<String, dynamic>;
        final intent = MealDecisionNotificationIntent.parse(
          value,
          json['action'] as String?,
        );
        if (intent != null) {
          records.add((
            intent: intent,
            at: (json['queuedAt'] as num?)?.toInt() ?? 0,
          ));
        }
      } catch (_) {
        /* Malformed local intents cannot authorize any backend action. */
      }
    }
    records.sort((a, b) => a.at.compareTo(b.at));
    return records.map((record) => record.intent).toList();
  }

  Future<void> add(MealDecisionNotificationIntent intent) async {
    // Independent keys avoid read/modify/write races between notification isolates.
    // Repeated identical taps are coalesced; distinct actions remain ordered.
    await preferences.setString(
      storageKey(intent),
      jsonEncode({
        ...jsonDecode(intent.encode()) as Map<String, dynamic>,
        'queuedAt': DateTime.now().microsecondsSinceEpoch,
      }),
    );
    changes.add(null);
  }

  Future<void> remove(MealDecisionNotificationIntent intent) =>
      preferences.remove(storageKey(intent));
}
