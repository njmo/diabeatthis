import 'dart:convert';

enum MealDecisionTimeoutFallback { app, manual }

enum MealDecisionMethod { app, ai, caregiver }

/// Configured intent. Remote decision delivery is a separate, future capability.
class MealDecisionPreferences {
  const MealDecisionPreferences({
    this.method = MealDecisionMethod.app,
    this.caregiverResponsesEnabled = true,
    this.deferralMinutes = 45,
    this.timeoutFallback = MealDecisionTimeoutFallback.app,
    this.allowManualDecision = true,
  });
  final MealDecisionMethod method;
  final bool caregiverResponsesEnabled;
  final int deferralMinutes;
  final MealDecisionTimeoutFallback timeoutFallback;
  final bool allowManualDecision;

  MealDecisionPreferences copyWith({
    MealDecisionMethod? method,
    bool? caregiverResponsesEnabled,
    int? deferralMinutes,
    MealDecisionTimeoutFallback? timeoutFallback,
    bool? allowManualDecision,
  }) => MealDecisionPreferences(
    method: method ?? this.method,
    allowManualDecision: allowManualDecision ?? this.allowManualDecision,
    timeoutFallback: timeoutFallback ?? this.timeoutFallback,
    deferralMinutes: deferralMinutes ?? this.deferralMinutes,
    caregiverResponsesEnabled:
        caregiverResponsesEnabled ?? this.caregiverResponsesEnabled,
  );

  String encode() => jsonEncode({
    'method': method.name,
    'allowManualDecision': allowManualDecision,
    'timeoutFallback': timeoutFallback.name,
    'deferralMinutes': deferralMinutes,
    'caregiverResponsesEnabled': caregiverResponsesEnabled,
  });
  static MealDecisionPreferences decode(String? value) {
    try {
      final json = jsonDecode(value ?? '{}') as Map;
      final allowManualDecision = json['allowManualDecision'] as bool? ?? true;
      return MealDecisionPreferences(
        allowManualDecision: allowManualDecision,
        timeoutFallback: !allowManualDecision
            ? MealDecisionTimeoutFallback.app
            : MealDecisionTimeoutFallback.values
                      .where((value) => value.name == json['timeoutFallback'])
                      .firstOrNull ??
                  MealDecisionTimeoutFallback.app,
        method:
            MealDecisionMethod.values
                .where((m) => m.name == json['method'])
                .firstOrNull ??
            MealDecisionMethod.app,
        caregiverResponsesEnabled:
            json['caregiverResponsesEnabled'] as bool? ?? true,
        deferralMinutes:
            json['deferralMinutes'] is int &&
                (json['deferralMinutes'] as int) > 0 &&
                (json['deferralMinutes'] as int) <= 180
            ? json['deferralMinutes'] as int
            : 45,
      );
    } catch (_) {
      return const MealDecisionPreferences();
    }
  }
}
