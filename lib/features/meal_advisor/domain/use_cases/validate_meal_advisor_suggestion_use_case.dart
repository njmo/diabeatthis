import 'dart:convert';

import '../../../../common/analysis/dml_evidence_references.dart';
import '../../../../common/meal/meal_decision.dart';
import '../../../meal_analysis/domain/models/before_meal_context.dart';
import '../models/meal_advice_eligibility.dart';
import '../models/meal_advisor_input.dart';
import '../models/meal_advisor_suggestion.dart';
import '../models/meal_advisor_suggestion_policy.dart';
import '../services/evaluate_meal_advice_eligibility.dart';
import 'check_meal_advisor_device_status_use_case.dart';

/// Validates model output against the exact request and current input freshness.
/// Performs no IO, does not calculate a dose and does not apply the suggestion.
class ValidateMealAdvisorSuggestionUseCase {
  const ValidateMealAdvisorSuggestionUseCase();

  MealAdvisorSuggestion call(
    String response, {
    required MealAdvisorInput input,
    required MealAdvisorSuggestionPolicy policy,
    required DateTime now,
  }) {
    final json = jsonDecode(response);
    const keys = {
      'schema_version',
      'request_id',
      'status',
      'action',
      'wait_minutes',
      'reason',
      'evidence',
      'missing_data',
    };
    if (json is! Map<String, dynamic> ||
        json.length != keys.length ||
        !keys.containsAll(json.keys) ||
        (json['schema_version'] is! int || json['schema_version'] != 1) ||
        json['request_id'] != input.requestId) {
      throw const FormatException('Invalid advisor response envelope');
    }
    final status = switch (json['status']) {
      'suggestion' => MealAdvisorSuggestionStatus.suggestion,
      'insufficient_data' => MealAdvisorSuggestionStatus.insufficientData,
      _ => throw const FormatException('Invalid advisor response status'),
    };
    final action = switch (json['action']) {
      'eatNowBolusLater' => MealDecision.eatNowBolusLater,
      'bolusAndEatNow' => MealDecision.bolusAndEatNow,
      'bolusWaitThenEat' => MealDecision.bolusWaitThenEat,
      null => null,
      _ => throw const FormatException('Unsupported advisor action'),
    };
    final wait = json['wait_minutes'];
    final reason = json['reason'];
    if (reason is! String ||
        reason.trim().isEmpty ||
        reason.length > 1000 ||
        (wait != null && wait is! int)) {
      throw const FormatException('Invalid advisor reason or waiting time');
    }
    final evidence = _strings(json['evidence'], maximum: 12);
    final missing = _strings(json['missing_data'], maximum: 12);
    final known = dmlEvidenceReferences(input.text, input.evidenceIds);
    if (!known.containsAll(evidence)) {
      throw const FormatException('Unknown advisor evidence reference');
    }
    if (status == MealAdvisorSuggestionStatus.insufficientData) {
      if (action != null || wait != null || missing.isEmpty) {
        throw const FormatException('An abstention must not contain advice');
      }
    } else {
      if (action == null ||
          !policy.allowedActions.contains(action) ||
          (action == MealDecision.bolusWaitThenEat
              ? wait is! int || wait < 1 || wait > policy.maximumWaitMinutes
              : wait != 0) ||
          !evidence.any(
            (e) => e == 'planned_meal' || e.startsWith('planned_meal.'),
          ) ||
          !evidence.any(
            (e) => e == 'current_before' || e.startsWith('current_before.'),
          )) {
        throw const FormatException(
          'Advice violates policy or lacks current evidence',
        );
      }
      _checkReadiness(input, policy, now);
    }
    return MealAdvisorSuggestion(
      requestId: input.requestId,
      status: status,
      action: action,
      waitMinutes: wait as int?,
      reason: reason.trim(),
      evidence: evidence,
      missingData: missing,
    );
  }

  List<String> _strings(Object? value, {required int maximum}) {
    if (value is! List ||
        value.length > maximum ||
        value.any((v) => v is! String || v.trim().isEmpty || v.length > 200)) {
      throw const FormatException('Invalid advisor evidence or missing data');
    }
    return value.cast<String>().toSet().toList();
  }

  void _checkReadiness(
    MealAdvisorInput input,
    MealAdvisorSuggestionPolicy policy,
    DateTime now,
  ) {
    final context = input.context;
    final before = context.before;
    final age = now.difference(before.asOf);
    final target = context.target;
    if (age.isNegative ||
        age >= policy.maximumContextAge ||
        context.builtAt.isBefore(before.asOf) ||
        context.builtAt.isAfter(now) ||
        context.failures.contains('cancelled') ||
        target == null ||
        target.mealId != before.mealId ||
        before.macros == null ||
        target.macros.netCarbsGrams != before.macros!.netCarbsGrams ||
        target.macros.fatGrams != before.macros!.fatGrams ||
        target.macros.proteinGrams != before.macros!.proteinGrams ||
        target.macros.fiberGrams != before.macros!.fiberGrams ||
        target.macros.totalGrams != before.macros!.totalGrams ||
        before.failedSources.contains(BeforeMealSource.glucose) ||
        before.failedSources.contains(BeforeMealSource.deviceStatus)) {
      throw StateError('Advisor context is unavailable or expired');
    }
    // Reuse the same checks used by foreground and the standard advisor.
    final cgm = evaluateMealAdviceEligibility(before.glucose ?? [], now);
    final pump = const CheckMealAdvisorDeviceStatusUseCase().evaluate(
      before.latestDeviceStatus,
      now,
    );
    if (cgm != MealAdviceEligibility.available ||
        pump != MealAdviceEligibility.available) {
      throw StateError('Advisor requires fresh continuous CGM and AAPS data');
    }
  }
}
