import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../remote/meal_decision_resolution.dart';
import 'child_meal_decision_sheet.dart';
import 'meal_decision_presentation_registry.dart';

/// Keeps the meal workflow mounted while the caregiver step replaces it visually.
class MealDecisionStepHost extends ConsumerStatefulWidget {
  const MealDecisionStepHost({
    super.key,
    required this.child,
    this.initialRequestId,
  });

  final Widget child;
  final String? initialRequestId;

  @override
  ConsumerState<MealDecisionStepHost> createState() =>
      MealDecisionStepHostState();
}

class MealDecisionStepHostState extends ConsumerState<MealDecisionStepHost> {
  Completer<MealDecisionResolution?>? pending;
  int? mealId;
  String? mealName;

  Future<MealDecisionResolution?> present(
    BuildContext context,
    int id,
    String name,
  ) async {
    if (!MealDecisionPresentationRegistry.childMeals.add(id)) return null;
    final request = Completer<MealDecisionResolution?>();
    setState(() {
      pending = request;
      mealId = id;
      mealName = name;
    });
    try {
      return await request.future;
    } finally {
      MealDecisionPresentationRegistry.childMeals.remove(id);
      if (mounted) setState(() => pending = null);
    }
  }

  @override
  void dispose() {
    final request = pending;
    if (request != null && !request.isCompleted) request.complete(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presenter = ref.watch(childMealDecisionRequestPresenterProvider);
    final request = pending;
    final content = Stack(
      children: [
        Offstage(offstage: request != null, child: widget.child),
        if (request != null)
          ChildMealDecisionSheet(
            mealId: mealId!,
            mealName: mealName!,
            initialRequestId: widget.initialRequestId,
            onResolved: (resolution) {
              if (!request.isCompleted) request.complete(resolution);
            },
          ),
      ],
    );
    if (presenter != presentChildMealDecisionRequest) return content;
    return ProviderScope(
      overrides: [
        childMealDecisionRequestPresenterProvider.overrideWithValue(present),
      ],
      child: content,
    );
  }
}
