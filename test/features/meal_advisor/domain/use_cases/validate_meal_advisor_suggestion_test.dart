import 'dart:convert';

import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/features/meal_advisor/data/prompts/meal_advisor_prompt.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_context.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_input.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_suggestion.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_suggestion_policy.dart';
import 'package:diabeatthis/features/meal_advisor/domain/serialization/meal_advisor_dml.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/validate_meal_advisor_suggestion_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../meal_analysis/build_before_meal_context_use_case_test.dart'
    show builder, cutoff, macros, reading;
import 'build_meal_advisor_context_test.dart' show plannedTarget;

final policy = MealAdvisorSuggestionPolicy(
  maximumWaitMinutes: 15,
  maximumContextAge: const Duration(minutes: 5),
  allowedActions: MealAdvisorSuggestionPolicy.supportedActions,
);
const validate = ValidateMealAdvisorSuggestionUseCase();
Map<String, Object?> response() => {
  'schema_version': 1,
  'request_id': 'request-1',
  'status': 'suggestion',
  'action': 'bolusWaitThenEat',
  'wait_minutes': 5,
  'reason': 'Current data and earlier meals should be compared with caution.',
  'evidence': ['planned_meal.net_carbs_g', 'current_before.latest_cgm_mg_dl'],
  'missing_data': <String>[],
};
Future<MealAdvisorInput> input({
  bool staleCgm = false,
  bool missingPump = false,
  bool cancelled = false,
}) async {
  final before = await builder(
    glucose: (_, _) async => staleCgm
        ? [reading(-20), reading(-15), reading(-10)]
        : [reading(-10), reading(-5), reading(0)],
    statuses: missingPump ? [] : null,
  )(asOf: cutoff, mealId: 1, macros: macros);
  return serializeMealAdvisorContext(
    MealAdvisorContext(
      before: before,
      target: plannedTarget(),
      builtAt: cutoff,
      comparisons: [],
      failures: cancelled ? {'cancelled'} : {},
    ),
    requestId: 'request-1',
  );
}

void main() {
  test(
    'only validated action and minutes are returned; validation performs no history IO',
    () async {
      final result = validate(
        jsonEncode(response()),
        input: await input(),
        policy: policy,
        now: cutoff,
      );
      expect(result.action, MealDecision.bolusWaitThenEat);
      expect(result.waitMinutes, 5);
      expect(result.status, MealAdvisorSuggestionStatus.suggestion);
      expect(() => result.evidence.add('invented'), throwsUnsupportedError);
    },
  );
  test('non-wait actions require exactly zero minutes', () async {
    final document = await input();
    for (final action in ['eatNowBolusLater', 'bolusAndEatNow']) {
      final json = response()
        ..['action'] = action
        ..['wait_minutes'] = 0;
      expect(
        validate(
          jsonEncode(json),
          input: document,
          policy: policy,
          now: cutoff,
        ).waitMinutes,
        0,
      );
      json['wait_minutes'] = 5;
      expect(
        () => validate(
          jsonEncode(json),
          input: document,
          policy: policy,
          now: cutoff,
        ),
        throwsFormatException,
      );
    }
  });
  test(
    'rejects mismatched request, invented evidence, unsupported dose fields and invalid minutes',
    () async {
      final document = await input();
      final mutations = <Map<String, Object?>>[
        {'request_id': 'other'},
        {
          'evidence': ['planned_meal', 'invented'],
        },
        {'insulin_units': 1.0},
        {'action': 'bolus'},
        {'wait_minutes': 16},
        {'wait_minutes': 0},
        {'wait_minutes': 5.5},
        {
          'evidence': ['similar_1'],
        },
        {'reason': ''},
      ];
      for (final mutation in mutations) {
        expect(
          () => validate(
            jsonEncode({...response(), ...mutation}),
            input: document,
            policy: policy,
            now: cutoff,
          ),
          throwsFormatException,
          reason: mutation.toString(),
        );
      }
    },
  );
  test('caller policy can disallow an otherwise supported action', () async {
    final document = await input();
    final limited = MealAdvisorSuggestionPolicy(
      maximumWaitMinutes: 15,
      maximumContextAge: const Duration(minutes: 5),
      allowedActions: {MealDecision.bolusAndEatNow},
    );
    expect(
      () => validate(
        jsonEncode(response()),
        input: document,
        policy: limited,
        now: cutoff,
      ),
      throwsFormatException,
    );
  });
  test(
    'stale input, stale CGM, missing pump and cancelled preparation cannot produce a suggestion',
    () async {
      final fresh = await input();
      expect(
        () => validate(
          jsonEncode(response()),
          input: fresh,
          policy: policy,
          now: cutoff.add(const Duration(minutes: 5)),
        ),
        throwsStateError,
      );
      expect(
        () => validate(
          jsonEncode(response()),
          input: fresh,
          policy: policy,
          now: cutoff.subtract(const Duration(seconds: 1)),
        ),
        throwsStateError,
      );
      for (final document in [
        await input(staleCgm: true),
        await input(missingPump: true),
        await input(cancelled: true),
      ]) {
        expect(
          () => validate(
            jsonEncode(response()),
            input: document,
            policy: policy,
            now: cutoff,
          ),
          throwsStateError,
        );
      }
    },
  );
  test(
    'explicit abstention is available even when required data is missing',
    () async {
      final json = response()
        ..['status'] = 'insufficient_data'
        ..['action'] = null
        ..['wait_minutes'] = null
        ..['evidence'] = <String>[]
        ..['missing_data'] = ['Fresh CGM is unavailable'];
      final document = await input(staleCgm: true);
      expect(
        validate(
          jsonEncode(json),
          input: document,
          policy: policy,
          now: cutoff,
        ).status,
        MealAdvisorSuggestionStatus.insufficientData,
      );
      json['action'] = 'bolusAndEatNow';
      expect(
        () => validate(
          jsonEncode(json),
          input: document,
          policy: policy,
          now: cutoff,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'prompt preserves exact evidence, binds request and forbids dose calculations',
    () async {
      final document = await input();
      final prompt = mealAdvisorPrompt(
        document,
        language: 'pl',
        policy: policy,
      );
      expect(
        prompt,
        contains('BEGIN_DML_DATA\n${document.text}\nEND_DML_DATA'),
      );
      expect(prompt, contains('Respond in pl'));
      expect(prompt, contains('request-1'));
      expect(prompt, contains('Never calculate insulin units'));
      expect(
        () => mealAdvisorPrompt(document, language: 'xx', policy: policy),
        throwsArgumentError,
      );
    },
  );
}
