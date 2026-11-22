import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/common/meal/meal_add_on_progress.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/common/meal_advisor/watch/caregiver_watch_meals.dart';
import 'package:diabeatthis/common/meal_advisor/watch/watch_meal_progress.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime.utc(2026, 11, 22, 12);
const foodFirst = MealDecision.eatNowBolusLater;
const immediate = MealDecision.bolusAndEatNow;
const waitFirst = MealDecision.bolusWaitThenEat;

MealAddOnBolusContext addOn(
  String origin, {
  required int remaining,
  bool previouslyRecorded = false,
  bool requiredBolus = true,
}) => MealAddOnBolusContext.decode(
  MealAddOnBolusContext(
    originalStatus: origin,
    eatingStartedAt: now,
    requestedAt: now,
    coveredCarbs: previouslyRecorded ? 20 : 0,
    statusCoveredCarbs: previouslyRecorded ? 20 : 0,
    reportedExtendedCarbs: 0,
    requestedCarbs: remaining,
    requestedExtendedCarbs: remaining > 0 ? 3 : 0,
    awaitingBolus: remaining > 0,
    bolusConfirmed: previouslyRecorded,
    additionalServing: true,
    bolusBeforeExtra: requiredBolus,
  ).encode(),
)!;

void main() {
  test('add-on shows its own eCarbs receipt while its bolus is pending', () {
    final pending = addOn(
      'waited-eating',
      remaining: 10,
      previouslyRecorded: true,
    );
    final before = watchMealProgress(
      'eating-extra',
      decision: waitFirst,
      addOn: pending,
      carbsEntered: true,
    );
    expect(before['stage'], 'bolus');
    expect(before['carbs'], 10);
    expect(before['carbsEntered'], isNot(true));
    expect(before['extendedCarbsConfirmed'], isNot(true));

    final after = watchMealProgress(
      'eating-extra',
      decision: waitFirst,
      addOn: pending.copyWith(extendedCarbsConfirmed: true),
    );
    expect(after['stage'], 'bolus');
    expect(after['carbsEntered'], isNot(true));
    expect(after['extendedCarbsConfirmed'], isTrue);
  });

  for (final (origin, decision) in [
    ('eating-then-bolus', foodFirst),
    ('bolused-eating', immediate),
    ('waited-eating', waitFirst),
  ]) {
    for (final (phase, remaining, prior, required) in [
      ('pending', 20, false, true),
      ('partial', 6, true, true),
      ('confirmed', 0, true, true),
      ('no second bolus', 0, false, false),
    ]) {
      test('both watches show the same extra phase for $origin / $phase', () {
        final local = addOn(
          origin,
          remaining: remaining,
          previouslyRecorded: prior,
          requiredBolus: required,
        );
        final [mirrored] = caregiverWatchMeals([
          {
            'payload': {
              'id': 1,
              'name': 'Lunch',
              'status': 'eating-extra',
              'add_on_progress':
                  '{"originalStatus":"$origin","awaitingBolus":${remaining > 0 ? 1 : 0},"additionalServing":1,"bolusBeforeExtra":${required ? 1 : 0}}',
            },
          },
        ], day: now);
        expect(mirrored.addOnProgress, addOnProgressForContext(local));
        final child = watchMealProgress(
          'eating-extra',
          addOn: local,
          decision: decision,
        );
        final caregiver = watchMealProgress(
          'eating-extra',
          mirroredAddOn: mirrored.addOnProgress,
          decision: decision,
        );
        for (final key in ['stage', 'index', 'count', 'completed']) {
          expect(caregiver[key], child[key], reason: key);
        }
        expect(caregiver['stage'], remaining > 0 ? 'bolus' : 'extra');
        expect(caregiver.containsKey('carbs'), isFalse);
      });
    }
  }

  test(
    'food-first initial bolus and bolus after extra remain distinct in the mirror',
    () {
      const initial =
          '{"originalStatus":"eating-then-bolus","awaitingBolus":1,"additionalServing":0,"bolusBeforeExtra":0}';
      const afterExtra =
          '{"originalStatus":"eating-then-bolus","awaitingBolus":1,"additionalServing":1,"bolusBeforeExtra":1}';
      final first = watchMealProgress(
        'waiting-for-bolus',
        mirroredAddOn: readMirroredAddOnProgress(initial),
      );
      final extra = watchMealProgress(
        'waiting-for-bolus',
        mirroredAddOn: readMirroredAddOnProgress(afterExtra),
      );
      expect((first['stage'], first['index'], first['count']), ('bolus', 1, 2));
      expect((extra['stage'], extra['index'], extra['count']), ('bolus', 2, 3));
    },
  );

  test('countdown exposes the real deadline and does not finish eating', () {
    final waiting = watchMealProgress(
      'bolused-waiting',
      decision: waitFirst,
      waitStartedAt: now,
      waitMinutes: 15,
    );
    expect(waiting['stage'], 'waiting');
    expect(
      waiting['waitUntilMs'],
      now.add(const Duration(minutes: 15)).millisecondsSinceEpoch,
    );
    expect(waiting['canFinishEating'], isNot(true));
    expect(waiting.containsKey('carbs'), isFalse);

    final confirmed = watchMealProgress('waited-eating', decision: waitFirst);
    expect(confirmed['stage'], 'eating');
    expect(confirmed['canFinishEating'], isTrue);
    expect(confirmed['completed'], [0, 1]);
  });

  for (final (decision, initial, count, eatingIndex) in [
    (foodFirst, 'eating-then-bolus', 2, 0),
    (immediate, 'bolused-eating', 2, 1),
    (waitFirst, 'waited-eating', 3, 2),
  ]) {
    test('ordinary meal has its expected sequence for $initial', () {
      final eating = watchMealProgress(initial, decision: decision);
      expect(eating['count'], count);
      expect(eating['index'], eatingIndex);
      expect(eating['stage'], 'eating');
      expect(eating['canFinishEating'], isTrue);

      final bolus = watchMealProgress(
        'waiting-for-bolus',
        decision: decision,
        carbs: 18,
        extendedCarbs: 4,
      );
      expect(bolus['stage'], 'bolus');
      expect(bolus['index'], decision == foodFirst ? 1 : 0);
      expect(bolus['canFinishEating'], isNot(true));
      expect(bolus['carbs'], 18);
      expect(bolus['extendedCarbs'], 4);
    });

    test('$initial: incomplete coverage keeps the bolus screen active', () {
      final bolusIndex = decision == foodFirst ? 1 : count;
      final stageCount = decision == foodFirst ? 3 : count + 2;
      for (final (remaining, acceptedAny) in [(18, false), (6, true)]) {
        final pending = watchMealProgress(
          'eating-extra',
          decision: decision,
          addOn: addOn(
            initial,
            remaining: remaining,
            previouslyRecorded: acceptedAny,
          ),
        );
        expect(pending['stage'], 'bolus');
        expect(pending['index'], bolusIndex);
        expect(pending['count'], stageCount);
        expect(pending['canFinishEating'], isNot(true));
        expect(pending['carbs'], remaining);
        expect(pending['extendedCarbs'], 3);
      }
      final delivered = watchMealProgress(
        'eating-extra',
        decision: decision,
        addOn: addOn(initial, remaining: 0, previouslyRecorded: true),
        carbs: 18,
        extendedCarbs: 4,
      );
      expect(delivered['stage'], 'extra');
      expect(delivered['index'], bolusIndex + 1);
      expect(delivered['count'], stageCount);
      expect(delivered['canFinishEating'], isTrue);
      expect(delivered.containsKey('carbs'), isFalse);
      expect(delivered.containsKey('extendedCarbs'), isFalse);
    });
  }

  test('an extra with no separate bolus goes straight to eating', () {
    final extra = watchMealProgress(
      'eating-extra',
      decision: waitFirst,
      addOn: addOn(
        'waited-eating',
        remaining: 0,
        previouslyRecorded: true,
        requiredBolus: false,
      ),
    );
    expect(extra['stage'], 'extra');
    expect(extra['index'], 3);
    expect(extra['count'], 4);
    expect(extra['canFinishEating'], isTrue);
  });
}
