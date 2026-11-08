import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../l10n/language.dart';
import '../meal_decision_preferences.dart';

/// Displays the request's deadline without changing its workflow state.
class MealDecisionDeadlinePanel extends HookWidget {
  const MealDecisionDeadlinePanel({
    super.key,
    required this.deadline,
    required this.fallback,
  });

  final DateTime deadline;
  final MealDecisionTimeoutFallback? fallback;

  @override
  Widget build(BuildContext context) {
    final now = useState(clock.now());
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        now.value = clock.now();
      });
      return timer.cancel;
    }, [deadline]);
    final remainingMicros = deadline.difference(now.value).inMicroseconds;
    final seconds = remainingMicros <= 0
        ? 0
        : (remainingMicros / Duration.microsecondsPerSecond).ceil();
    final time =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final lang = context.lang;
    final colors = Theme.of(context).colorScheme;
    final fallbackDescription = switch (fallback) {
      MealDecisionTimeoutFallback.manual =>
        lang.mealDecisionDeadlineFallbackManual,
      MealDecisionTimeoutFallback.app => lang.mealDecisionDeadlineFallbackApp,
      null => lang.mealDecisionDeadlineFallbackUnknown,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.schedule, color: colors.onSurfaceVariant, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.mealDecisionDeadlineRemaining(time),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                fallbackDescription,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
