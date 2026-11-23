import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'meal_calculator_request.dart';
import 'meal_calculator_request_store.dart';

final mealCalculatorEntriesProvider = FutureProvider.autoDispose<Set<int>>((
  ref,
) async {
  if (kIsWeb || !Platform.isAndroid) return {};
  return recordedMealCalculatorEntries(
    (await PreferencesMealCalculatorRequestStore().read()).map(
      MealCalculatorRequest.fromJson,
    ),
  );
});

Set<int> recordedMealCalculatorEntries(
  Iterable<MealCalculatorRequest> requests,
) => {
  for (final request in requests)
    if (request.event.mealId case final mealId?)
      if (request.matchesMealStage(mealId, null) &&
          request.tracker.carbsEntered)
        mealId,
};
