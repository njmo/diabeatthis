import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../l10n/language.dart';
import '../../../widgets/meal_start/meal_start_sheet.dart';
import '../../meal_decision_preferences.dart';
import '../../remote/meal_decision_remote_request.dart';
import 'meal_decision_caregiver_roster.dart';
import 'meal_decision_meal_reference.dart';

class ChildMealDecisionFallbackNotice extends HookWidget {
  const ChildMealDecisionFallbackNotice({
    super.key,
    required this.mealName,
    required this.request,
    required this.fallback,
    required this.onContinue,
  });
  final String mealName;
  final MealDecisionRemoteRequest request;
  final MealDecisionTimeoutFallback fallback;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final remaining = useState(5);
    final completed = useRef(false);
    void proceed() {
      if (completed.value) return;
      completed.value = true;
      onContinue();
    }

    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (completed.value) return;
        remaining.value--;
        if (remaining.value <= 0) proceed();
      });
      return timer.cancel;
    }, [request.id]);
    return PopScope(
      canPop: false,
      child: MealStartSheet(
        title: context.lang.mealDecisionAllDeclinedTitle,
        subtitle: '',
        showClose: false,
        maxHeightFactor: .75,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MealDecisionMealReference(name: mealName),
            const SizedBox(height: 20),
            MealDecisionCaregiverRoster(request: request),
            const SizedBox(height: 8),
            Text(
              fallback == MealDecisionTimeoutFallback.manual
                  ? context.lang.mealDecisionFallbackManualNext
                  : context.lang.mealDecisionFallbackAppNext,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              context.lang.mealDecisionFallbackCountdown(remaining.value),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: FilledButton(
          onPressed: proceed,
          child: Text(context.lang.mealDecisionFallbackContinue),
        ),
      ),
    );
  }
}
