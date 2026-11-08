import 'package:clock/clock.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_answer.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_controller.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_request.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final method in MealDecisionTimeoutFallback.values) {
    test(
      'global child timeout cannot be extended by a handoff; fallback=$method',
      () async {
        var now = DateTime(2026, 11, 8, 12);
        await withClock(Clock(() => now), () async {
          final container = ProviderContainer(
            overrides: [
              googleAccountProvider.overrideWith((ref) => Stream.value(null)),
              mealDecisionDemoDelayProvider.overrideWithValue(() async {}),
              mealDecisionPreferencesProvider.overrideWithValue(
                MealDecisionPreferences(timeoutFallback: method),
              ),
            ],
          );
          addTearDown(container.dispose);
          final controller = container.read(
            mealDecisionDemoControllerProvider.notifier,
          );
          await controller.send(
            'meal',
            'Lunch',
            mealId: 42,
            childOwner: 'child-a',
            mirrorSource: 'mirror-a',
          );
          final original = container.read(
            mealDecisionDemoControllerProvider,
          )['meal']!;
          expect(
            original.toRequestPayload().keys,
            unorderedEquals(['requestId', 'mealId', 'requestedAt']),
          );
          expect(original.matchesFamily('child-b', 'mirror-a'), isFalse);
          expect(original.matchesFamily('child-a', 'mirror-b'), isFalse);
          expect(controller.claim('meal', original.id, 'Anna'), isTrue);
          expect(
            controller.transfer('meal', original.id, 'other', 'demo-second'),
            isFalse,
          );
          now = now.add(const Duration(minutes: 4));
          expect(
            controller.transfer(
              'meal',
              original.id,
              'demo-caregiver',
              'demo-second',
            ),
            isTrue,
          );
          final transferred = container.read(
            mealDecisionDemoControllerProvider,
          )['meal']!;
          expect(transferred.responseDeadline, original.responseDeadline);
          expect(transferred.claimExpiresAt, original.responseDeadline);
          expect(transferred.transferredFrom, 'Anna');
          expect(transferred.transferredTo, 'Adam');
          expect(
            controller.respond(
              'meal',
              original.id,
              answer: MealDecisionDemoAnswer.insulinAndEat,
              minutes: 0,
              caregiverName: 'Anna',
            ),
            isFalse,
          );
          expect(controller.expireRequest('meal', original.id), isFalse);
          now = original.responseDeadline;
          expect(controller.expireRequest('meal', original.id), isTrue);
          final expired = container.read(
            mealDecisionDemoControllerProvider,
          )['meal']!;
          expect(expired.status, MealDecisionDemoStatus.timedOut);
          expect(expired.fallbackAdvice, isNull);
          expect(expired.timeoutFallback, method);
          expect(
            controller.claim(
              'meal',
              original.id,
              'Adam',
              caregiverId: 'demo-second',
            ),
            isFalse,
          );
          expect(
            controller.respond(
              'meal',
              original.id,
              answer: MealDecisionDemoAnswer.insulinAndEat,
              minutes: 0,
              caregiverName: 'Adam',
              caregiverId: 'demo-second',
            ),
            isFalse,
          );
          final wrongSource = MealAdvice(
            MealDecisionDemoAnswer.eatThenInsulin.decision,
            null,
            source: 'caregiver',
          );
          expect(
            controller.completeFallback('meal', original.id, wrongSource),
            isFalse,
          );
          final chosen = MealAdvice(
            MealDecisionDemoAnswer.eatThenInsulin.decision,
            null,
            source: method == MealDecisionTimeoutFallback.app
                ? 'mealAdvisorDemo'
                : 'manualDemo',
          );
          expect(
            controller.completeFallback('meal', original.id, chosen),
            isTrue,
          );
          expect(
            container
                .read(mealDecisionDemoControllerProvider)['meal']!
                .fallbackAdvice,
            same(chosen),
          );
          expect(
            controller.completeFallback('meal', original.id, chosen),
            isFalse,
          );
          await controller.send('meal', 'New lunch', mealId: 43);
          expect(
            controller.completeFallback('meal', original.id, chosen),
            isFalse,
          );
          expect(
            container.read(mealDecisionDemoControllerProvider)['meal']!.mealId,
            43,
          );
        });
      },
    );
  }

  test(
    'timeout fallback preference is compatible with older saved options',
    () {
      expect(
        MealDecisionPreferences.decode('{}').timeoutFallback,
        MealDecisionTimeoutFallback.app,
      );
      expect(
        MealDecisionPreferences.decode(
          '{"timeoutFallback":"unknown"}',
        ).timeoutFallback,
        MealDecisionTimeoutFallback.app,
      );
      final saved = const MealDecisionPreferences(
        timeoutFallback: MealDecisionTimeoutFallback.manual,
      ).encode();
      expect(
        MealDecisionPreferences.decode(saved).timeoutFallback,
        MealDecisionTimeoutFallback.manual,
      );
    },
  );
}
