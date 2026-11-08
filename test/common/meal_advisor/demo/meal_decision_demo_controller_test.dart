import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_answer.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_controller.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer demoContainer({Future<void> Function()? delay}) =>
    ProviderContainer(
      overrides: [
        googleAccountProvider.overrideWith((ref) => Stream.value(null)),
        mealDecisionDemoDelayProvider.overrideWithValue(delay ?? () async {}),
      ],
    );

void main() {
  test(
    'an account reset while sending cannot be undone by a late delivery',
    () async {
      final delivery = Completer<void>();
      final accounts = StreamController<GoogleAccount?>.broadcast();
      final container = ProviderContainer(
        overrides: [
          googleAccountProvider.overrideWith((ref) => accounts.stream),
          mealDecisionDemoDelayProvider.overrideWithValue(
            () => delivery.future,
          ),
        ],
      );
      final subscription = container.listen(
        mealDecisionDemoControllerProvider,
        (_, _) {},
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await accounts.close();
      });
      accounts.add(const GoogleAccount(uid: 'first'));
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(
        mealDecisionDemoControllerProvider.notifier,
      );
      final sending = controller.send('patient:1', 'Lunch');
      expect(
        container.read(mealDecisionDemoControllerProvider)['patient:1']!.status,
        MealDecisionDemoStatus.sending,
      );
      await controller.send('patient:1', 'Duplicate');
      expect(container.read(mealDecisionDemoControllerProvider).length, 1);
      accounts.add(const GoogleAccount(uid: 'second'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(mealDecisionDemoControllerProvider), isEmpty);
      delivery.complete();
      await sending;
      expect(container.read(mealDecisionDemoControllerProvider), isEmpty);
    },
  );
  for (final answer in MealDecisionDemoAnswer.values) {
    test(
      'only the matching concrete $answer response can be acknowledged',
      () => withClock(Clock.fixed(DateTime(2026, 11, 8, 9)), () async {
        final container = demoContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          mealDecisionDemoControllerProvider.notifier,
        );
        await controller.send('patient:1', 'Lunch');
        final request = container.read(
          mealDecisionDemoControllerProvider,
        )['patient:1']!;
        expect(controller.acknowledge(request.key, request.id), isFalse);
        if (answer.requiresMinutes) {
          expect(
            controller.respond(
              request.key,
              request.id,
              answer: answer,
              minutes: 0,
              caregiverName: 'Anna',
            ),
            isFalse,
          );
        }
        expect(
          controller.respond(
            request.key,
            request.id,
            answer: answer,
            minutes: 45,
            caregiverName: 'Anna',
            message: 'Message',
            suggestMealTarget: true,
          ),
          isTrue,
        );
        final response = container.read(
          mealDecisionDemoControllerProvider,
        )[request.key]!;
        expect(identical(response.snapshot, request.snapshot), isTrue);
        expect(response.caregiverName, 'Anna');
        expect(response.waitMinutes, answer.requiresMinutes ? 45 : 0);
        expect(
          response.suggestMealTarget,
          answer == MealDecisionDemoAnswer.deferMeal,
        );
        expect(
          response.deferredUntil,
          answer == MealDecisionDemoAnswer.deferMeal
              ? DateTime(2026, 11, 8, 9, 45)
              : null,
        );
        expect(
          controller.respond(
            request.key,
            request.id,
            answer: answer,
            minutes: 45,
            caregiverName: 'Another',
          ),
          isFalse,
        );
        expect(controller.acknowledge(request.key, request.id), isTrue);
        expect(controller.acknowledge(request.key, request.id), isFalse);
        expect(
          container
              .read(mealDecisionDemoControllerProvider)[request.key]!
              .status,
          MealDecisionDemoStatus.accepted,
        );
        await controller.send(request.key, 'Retry');
        final retry = container.read(
          mealDecisionDemoControllerProvider,
        )[request.key]!;
        expect(retry.id, isNot(request.id));
        expect(
          controller.respond(
            request.key,
            request.id,
            answer: answer,
            minutes: 45,
            caregiverName: 'Anna',
          ),
          isFalse,
        );
        expect(controller.acknowledge(request.key, request.id), isFalse);
        expect(retry.status, MealDecisionDemoStatus.waiting);
      }),
    );
  }
  test('different demo meals cannot consume one another’s response', () async {
    final container = demoContainer();
    addTearDown(container.dispose);
    final controller = container.read(
      mealDecisionDemoControllerProvider.notifier,
    );
    await controller.send('patient:1', 'Lunch');
    await controller.send('caregiver:inbox', 'Dinner');
    final child = container.read(
      mealDecisionDemoControllerProvider,
    )['patient:1']!;
    expect(
      controller.respond(
        'caregiver:inbox',
        child.id,
        answer: MealDecisionDemoAnswer.insulinAndEat,
        minutes: 0,
        caregiverName: 'Anna',
      ),
      isFalse,
    );
    expect(
      container
          .read(mealDecisionDemoControllerProvider)
          .values
          .every((r) => r.status == MealDecisionDemoStatus.waiting),
      isTrue,
    );
  });
  test(
    'changing Google accounts discards all sample requests and stale replies',
    () async {
      final accounts = StreamController<GoogleAccount?>.broadcast();
      final container = ProviderContainer(
        overrides: [
          googleAccountProvider.overrideWith((ref) => accounts.stream),
          mealDecisionDemoDelayProvider.overrideWithValue(() async {}),
        ],
      );
      final subscription = container.listen(
        mealDecisionDemoControllerProvider,
        (_, _) {},
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await accounts.close();
      });
      accounts.add(const GoogleAccount(uid: 'first'));
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(
        mealDecisionDemoControllerProvider.notifier,
      );
      await controller.send('patient:1', 'Lunch');
      final original = container.read(
        mealDecisionDemoControllerProvider,
      )['patient:1']!;
      accounts.add(const GoogleAccount(uid: 'second'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(mealDecisionDemoControllerProvider), isEmpty);
      expect(
        controller.respond(
          original.key,
          original.id,
          answer: MealDecisionDemoAnswer.insulinAndEat,
          minutes: 0,
          caregiverName: 'Anna',
        ),
        isFalse,
      );
    },
  );
}
