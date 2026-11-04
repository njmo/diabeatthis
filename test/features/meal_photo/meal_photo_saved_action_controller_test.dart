import 'dart:async';

import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_saved_action_outcome.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_saved_action_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class SavedMealActionMocks {
  int reads = 0;
  int presentations = 0;
  int applications = 0;
  Object? readFailure;
  Object? applyFailure;
  String? response = 'start-eating';
  Completer<Meal?>? pendingRead;
  final applied = <String>[];
  final finished = <MealPhotoSavedActionOutcome>[];
  Future<Meal?> read(int id) async {
    reads++;
    if (readFailure case final error?) throw error;
    return pendingRead == null
        ? Meal(id: id, name: 'Persisted plate', status: 'planned')
        : pendingRead!.future;
  }

  Future<String?> present(Meal meal) async {
    presentations++;
    expect(meal.name, 'Persisted plate');
    return response;
  }

  Future<void> apply(Meal meal, String action) async {
    applications++;
    applied.add('${meal.id}:$action');
    if (applyFailure case final error?) throw error;
  }

  MealPhotoSavedActionController<String> controller() =>
      MealPhotoSavedActionController(
        readMeal: read,
        presentActions: present,
        applyAction: apply,
        onFinished: finished.add,
      );
}

void main() {
  test(
    'planned meal completes without reading or presenting any eating action',
    () async {
      final mocks = SavedMealActionMocks();
      final controller = mocks.controller();
      addTearDown(controller.dispose);
      final result = await controller.process(42, eatNow: false);
      expect(result.mealId, 42);
      expect(result.actionFailed, isFalse);
      expect(mocks.reads, 0);
      expect(mocks.presentations, 0);
      expect(mocks.applications, 0);
      expect(mocks.finished, [result]);
      expect(controller.busy, isFalse);
    },
  );
  test(
    'dismissing eat-now dialog keeps the already-saved meal without applying an action',
    () async {
      final mocks = SavedMealActionMocks()..response = null;
      final controller = mocks.controller();
      addTearDown(controller.dispose);
      final result = await controller.process(42, eatNow: true);
      expect(result.actionFailed, isFalse);
      expect(mocks.reads, 1);
      expect(mocks.presentations, 1);
      expect(mocks.applications, 0);
      expect(mocks.finished.single.mealId, 42);
    },
  );
  test(
    'accepted action receives the persisted meal and is applied exactly once',
    () async {
      final mocks = SavedMealActionMocks();
      final controller = mocks.controller();
      addTearDown(controller.dispose);
      final first = controller.process(42, eatNow: true);
      final repeated = controller.process(42, eatNow: true);
      expect(identical(first, repeated), isTrue);
      final result = await first;
      expect(result.actionFailed, isFalse);
      expect(identical(controller.process(42, eatNow: true), first), isTrue);
      expect(mocks.reads, 1);
      expect(mocks.presentations, 1);
      expect(mocks.applications, 1);
      expect(mocks.applied, ['42:start-eating']);
      expect(mocks.finished.length, 1);
    },
  );
  test(
    'failed action is a post-save failure and repeated callbacks do not retry it',
    () async {
      final failure = StateError('Action failed');
      final mocks = SavedMealActionMocks()..applyFailure = failure;
      final controller = mocks.controller();
      addTearDown(controller.dispose);
      final result = await controller.process(42, eatNow: true);
      expect(result.error, same(failure));
      expect(result.mealId, 42);
      expect(controller.outcome, same(result));
      expect(controller.busy, isFalse);
      expect(await controller.process(42, eatNow: true), same(result));
      expect(mocks.applications, 1);
      expect(mocks.reads, 1);
      expect(mocks.finished.length, 1);
    },
  );
  test(
    'failed saved-meal read cannot recreate a meal or retry its lookup',
    () async {
      final failure = StateError('Read failed');
      final mocks = SavedMealActionMocks()..readFailure = failure;
      final controller = mocks.controller();
      addTearDown(controller.dispose);
      final result = await controller.process(42, eatNow: true);
      await controller.process(42, eatNow: true);
      expect(result.error, same(failure));
      expect(mocks.reads, 1);
      expect(mocks.presentations, 0);
      expect(mocks.applications, 0);
      expect(mocks.finished.single.mealId, 42);
      expect(controller.busy, isFalse);
    },
  );
  test(
    'busy guard lasts across the asynchronous read; disposal prevents subsequent dialogs',
    () async {
      final mocks = SavedMealActionMocks()..pendingRead = Completer<Meal?>();
      final controller = mocks.controller();
      final pending = controller.process(42, eatNow: true);
      expect(controller.busy, isTrue);
      expect(identical(controller.process(42, eatNow: true), pending), isTrue);
      await expectLater(controller.process(43, eatNow: true), throwsStateError);
      controller.dispose();
      mocks.pendingRead!.complete(
        const Meal(id: 42, name: 'Persisted plate', status: 'planned'),
      );
      await pending;
      expect(mocks.reads, 1);
      expect(mocks.presentations, 0);
      expect(mocks.applications, 0);
      expect(mocks.finished, isEmpty);
    },
  );
}
