import 'package:flutter/foundation.dart';

void mealDecisionTiming(String phase, {int? elapsedMs}) {
  if (!kDebugMode) return;
  debugPrint(
    'MealDecisionTiming $phase${elapsedMs == null ? '' : ' ms=$elapsedMs'}',
  );
}

Future<T> timeMealDecision<T>(String phase, Future<T> Function() action) async {
  if (!kDebugMode) return action();
  final stopwatch = Stopwatch()..start();
  mealDecisionTiming('$phase.start');
  try {
    final result = await action();
    mealDecisionTiming('$phase.done', elapsedMs: stopwatch.elapsedMilliseconds);
    return result;
  } catch (_) {
    mealDecisionTiming(
      '$phase.error',
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
    rethrow;
  }
}
