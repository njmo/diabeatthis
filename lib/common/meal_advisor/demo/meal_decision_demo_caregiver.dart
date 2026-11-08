import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Demo roster only; production must use the authenticated child's family roster.
class MealDecisionDemoCaregiver {
  const MealDecisionDemoCaregiver(this.id, this.name);
  final String id, name;
}

final mealDecisionDemoCaregiversProvider =
    Provider<List<MealDecisionDemoCaregiver>>(
      (ref) => const [
        MealDecisionDemoCaregiver('demo-caregiver', 'Anna'),
        MealDecisionDemoCaregiver('demo-second', 'Adam'),
      ],
    );
