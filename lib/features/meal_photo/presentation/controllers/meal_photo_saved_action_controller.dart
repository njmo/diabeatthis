import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/domain/model/meal.dart';
import '../../domain/models/meal_photo_saved_action_outcome.dart';

/// Coordinates actions after persistence, never creating or saving a meal again.
class MealPhotoSavedActionController<T> extends ChangeNotifier {
  MealPhotoSavedActionController({
    required this.readMeal,
    required this.presentActions,
    required this.applyAction,
    this.onFinished,
  });
  final Future<Meal?> Function(int mealId) readMeal;
  final Future<T?> Function(Meal meal) presentActions;
  final Future<void> Function(Meal meal, T action) applyAction;
  final void Function(MealPhotoSavedActionOutcome outcome)? onFinished;
  final Map<int, Future<MealPhotoSavedActionOutcome>> _operations = {};
  bool _busy = false;
  bool get busy => _busy;
  bool _disposed = false;
  MealPhotoSavedActionOutcome? _outcome;
  MealPhotoSavedActionOutcome? get outcome => _outcome;

  Future<MealPhotoSavedActionOutcome> process(
    int mealId, {
    required bool eatNow,
  }) {
    final previous = _operations[mealId];
    if (previous != null) return previous;
    if (_disposed || _busy) {
      return Future.error(StateError('A saved meal action cannot start now'));
    }
    final completion = Completer<MealPhotoSavedActionOutcome>();
    _operations[mealId] = completion.future;
    _busy = true;
    notifyListeners();
    unawaited(_run(mealId, eatNow: eatNow).then(completion.complete));
    return completion.future;
  }

  Future<MealPhotoSavedActionOutcome> _run(
    int mealId, {
    required bool eatNow,
  }) async {
    Object? error;
    StackTrace? stack;
    try {
      if (eatNow) {
        final meal = await readMeal(mealId);
        if (!_disposed) {
          if (meal == null) {
            throw StateError('Saved meal is no longer available');
          }
          final action = await presentActions(meal);
          if (!_disposed && action != null) await applyAction(meal, action);
        }
      }
    } catch (failure, trace) {
      error = failure;
      stack = trace;
    }
    var result = MealPhotoSavedActionOutcome(
      mealId: mealId,
      error: error,
      stackTrace: stack,
    );
    _outcome = result;
    _busy = false;
    if (!_disposed) {
      notifyListeners();
      try {
        onFinished?.call(result);
      } catch (failure, trace) {
        result = MealPhotoSavedActionOutcome(
          mealId: mealId,
          error: failure,
          stackTrace: trace,
        );
        _outcome = result;
      }
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
