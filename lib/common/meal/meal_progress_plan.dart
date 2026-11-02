import 'meal_add_on_bolus_context.dart';
import 'meal_decision.dart';

enum MealProgressStage { bolus, waiting, eating, extra }

class MealProgressPlan {
  const MealProgressPlan({
    required this.stages,
    required this.currentIndex,
    this.pendingIndices = const {},
  });

  final List<MealProgressStage> stages;
  final int currentIndex;
  final Set<int> pendingIndices;

  bool isComplete(int index) =>
      index < currentIndex && !pendingIndices.contains(index);
}

MealProgressPlan mealProgressPlanForStatus(
  String? status, {
  MealDecision? decision,
  Iterable<String> history = const [],
  MealAddOnBolusContext? addOn,
}) {
  if (addOn != null &&
      (status == 'eating-extra' || status == 'waiting-for-bolus')) {
    if (status == 'waiting-for-bolus') {
      return const MealProgressPlan(
        stages: [
          MealProgressStage.eating,
          MealProgressStage.extra,
          MealProgressStage.bolus,
        ],
        currentIndex: 2,
      );
    }
    final original = mealProgressPlanForStatus(
      addOn.originalStatus,
      decision: decision,
      history: history,
    );
    final stages = [
      ...original.stages.where((stage) => stage != MealProgressStage.extra),
      MealProgressStage.extra,
    ];
    return MealProgressPlan(
      stages: stages,
      currentIndex: stages.length - 1,
      pendingIndices: {
        if (!addOn.bolusConfirmed)
          for (var index = 0; index < stages.length; index++)
            if (stages[index] == MealProgressStage.bolus) index,
      },
    );
  }
  final ateBeforeBolus =
      status == 'eating-then-bolus' ||
      history.contains('eating-then-bolus') ||
      decision == MealDecision.eatNowBolusLater;
  final waited =
      status == 'bolused-waiting' ||
      status == 'waited-eating' ||
      history.contains('bolused-waiting') ||
      history.contains('waited-eating') ||
      decision == MealDecision.bolusWaitThenEat;

  if (ateBeforeBolus) {
    if (status == 'eating-extra' && history.contains('eaten-bolused')) {
      return const MealProgressPlan(
        stages: [
          MealProgressStage.eating,
          MealProgressStage.bolus,
          MealProgressStage.extra,
        ],
        currentIndex: 2,
      );
    }
    return MealProgressPlan(
      stages: const [MealProgressStage.eating, MealProgressStage.bolus],
      currentIndex: status == 'waiting-for-bolus' ? 1 : 0,
    );
  }
  if (waited) {
    return MealProgressPlan(
      stages: const [
        MealProgressStage.bolus,
        MealProgressStage.waiting,
        MealProgressStage.eating,
      ],
      currentIndex: status == 'waiting-for-bolus'
          ? 0
          : status == 'bolused-waiting'
          ? 1
          : 2,
    );
  }
  if (status == 'bolused-eating' ||
      history.contains('bolused-eating') ||
      decision == MealDecision.bolusAndEatNow) {
    return MealProgressPlan(
      stages: const [MealProgressStage.bolus, MealProgressStage.eating],
      currentIndex: status == 'waiting-for-bolus' ? 0 : 1,
    );
  }
  // An unknown decision must not invent either a waiting phase or a bolus.
  return MealProgressPlan(
    stages: [
      status == 'waiting-for-bolus'
          ? MealProgressStage.bolus
          : MealProgressStage.eating,
    ],
    currentIndex: 0,
  );
}
