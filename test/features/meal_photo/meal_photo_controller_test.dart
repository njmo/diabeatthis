import 'dart:async';

import 'package:diabeatthis/features/meal_photo/domain/models/accepted_meal_photo_review.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_candidate.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/ports/meal_photo_candidate_repository.dart';
import 'package:diabeatthis/features/meal_photo/domain/ports/meal_photo_meal_saver.dart';
import 'package:diabeatthis/features/meal_photo/domain/ports/meal_photo_recognition_client.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

class TestPhotoClient implements MealPhotoRecognitionClient {
  Completer<String>? pending;
  String? resolved;
  Map<String, List<MealPhotoCandidate>>? supplied;
  @override
  Future<String> describe(MealPhotoInput input) async =>
      pending == null ? (resolved ?? fixtures.proposal()) : pending!.future;
  @override
  Future<String> resolve(
    MealPhotoInput input,
    String descriptionResponse,
    Map<String, List<MealPhotoCandidate>> candidates,
  ) async {
    supplied = candidates;
    return resolved ?? fixtures.proposal();
  }
}

class TestPhotoCandidates implements MealPhotoCandidateRepository {
  final queries = <String>[];
  @override
  Future<List<MealPhotoCandidate>> search(
    String query, {
    required String languageCode,
    int limit = 8,
  }) async {
    queries.add('$languageCode:$query');
    return [fixtures.candidate];
  }
}

class TestPhotoSaver implements MealPhotoMealSaver {
  int calls = 0;
  AcceptedMealPhotoReview? accepted;
  final result = Completer<int>();
  @override
  Future<int> save(AcceptedMealPhotoReview review) {
    calls++;
    accepted = review;
    return result.future;
  }
}

void main() {
  test('proposal does not search products before division', () async {
    final client = TestPhotoClient();
    final candidates = TestPhotoCandidates();
    final result = await ProposeMealFromPhotoUseCase(
      client: client,
      candidates: candidates,
    )(const MealPhotoInput(mealPhotoPath: 'meal.jpg'), languageCode: 'pl');
    expect(candidates.queries, isEmpty);
    expect(client.supplied, isNull);
    expect(result.itemized.single.name, 'Cooked potatoes');
  });
  test(
    'model cannot assign a catalog identity without supplied candidates',
    () async {
      final client = TestPhotoClient()
        ..resolved = fixtures.proposal(
          item: fixtures.component('potatoes', kind: 'matched', key: 'local:7'),
        );
      await expectLater(
        ProposeMealFromPhotoUseCase(
          client: client,
          candidates: TestPhotoCandidates(),
        )(const MealPhotoInput(mealPhotoPath: 'plate.jpg'), languageCode: 'en'),
        throwsFormatException,
      );
    },
  );
  test(
    'review gates save, preserves total reference nutrition, and guards duplicate writes',
    () async {
      final saver = TestPhotoSaver();
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: TestPhotoClient(),
          candidates: TestPhotoCandidates(),
        ),
        saver: saver,
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const MealPhotoInput(
          mealPhotoPath: 'meal.jpg',
          description: 'Potatoes and other meal ingredients',
        ),
        languageCode: 'pl',
      );
      controller.chooseMode(MealPhotoMode.reference);
      expect(controller.next, throwsStateError);
      controller.acceptReference('plate');
      controller.next();
      expect(controller.next, throwsStateError);
      controller.setAmount(
        'plate',
        grams: 200,
        quantityConfidence: .7,
        nutritionConfidence: .6,
        reviewed: true,
      );
      controller.next();
      expect(() => controller.save(confirmed: false), throwsStateError);
      final first = controller.save(confirmed: true);
      final second = controller.save(confirmed: true);
      expect(identical(first, second), isTrue);
      expect(saver.calls, 1);
      expect(controller.cancel, throwsStateError);
      expect(controller.state.saving, isTrue);
      expect(saver.accepted!.items.single.nutritionForPortion!.carbs, 30);
      expect(saver.accepted!.items.single.weightGrams, 200);
      saver.result.complete(42);
      expect(await first, 42);
      expect(controller.state.step, MealPhotoStep.saved);
    },
  );
  test(
    'whole plate cannot become a catalog item and post-confirmation edits require confirmation again',
    () async {
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: TestPhotoClient(),
          candidates: TestPhotoCandidates(),
        ),
        saver: TestPhotoSaver(),
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const MealPhotoInput(
          mealPhotoPath: 'meal.jpg',
          description: 'Potatoes and other meal ingredients',
        ),
        languageCode: 'en',
      );
      controller.chooseMode(MealPhotoMode.reference);
      expect(
        () => controller.assignProduct('plate', fixtures.candidate),
        throwsStateError,
      );
      controller.acceptReference('plate');
      controller.next();
      controller.setAmount(
        'plate',
        grams: 200,
        quantityConfidence: .7,
        nutritionConfidence: .6,
        reviewed: true,
      );
      controller.next();
      controller.setAmount(
        'plate',
        grams: 250,
        quantityConfidence: .8,
        nutritionConfidence: .6,
        reviewed: true,
      );
      expect(controller.state.step, MealPhotoStep.amounts);
      expect(() => controller.save(confirmed: true), throwsStateError);
    },
  );
  test('cancelled recognition cannot revive a discarded proposal', () async {
    final client = TestPhotoClient()..pending = Completer<String>();
    final controller = MealPhotoController(
      propose: ProposeMealFromPhotoUseCase(
        client: client,
        candidates: TestPhotoCandidates(),
      ),
      saver: TestPhotoSaver(),
    );
    addTearDown(controller.dispose);
    final pending = controller.generate(
      const MealPhotoInput(
        mealPhotoPath: 'meal.jpg',
        description: 'Potatoes and other meal ingredients',
      ),
      languageCode: 'en',
    );
    controller.cancel();
    client.pending!.complete(fixtures.proposal());
    await pending;
    expect(controller.state.step, MealPhotoStep.capture);
    expect(controller.state.proposal, isNull);
  });
}
