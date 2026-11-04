import 'dart:convert';

import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_clarification_required.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal_stage.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_clarification_test.dart';
import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  test('proposal progress contains only recognition and validation', () async {
    final client = ClarifyingPhotoClient(
      first: fixtures.proposal(),
      second: fixtures.proposal(),
    );
    final stages = <MealPhotoProposalStage>[];
    await ProposeMealFromPhotoUseCase(
      client: client,
      candidates: ClarificationCandidateReads(),
    )(
      const MealPhotoInput(mealPhotoPath: 'plate.jpg', description: 'Potatoes'),
      languageCode: 'en',
      onProgress: stages.add,
    );
    expect(stages, [
      MealPhotoProposalStage.recognizing,
      MealPhotoProposalStage.validating,
    ]);
  });
  test(
    'clarification stops progress at validation before any catalog or resolution stage',
    () async {
      final client = ClarifyingPhotoClient(
        first: jsonEncode(clarificationPayload(reason: 'missing_menu')),
        second: fixtures.proposal(),
      );
      final stages = <MealPhotoProposalStage>[];
      await expectLater(
        ProposeMealFromPhotoUseCase(
          client: client,
          candidates: ClarificationCandidateReads(),
        )(
          const MealPhotoInput(
            mealPhotoPath: 'plate.jpg',
            description: 'Menu position 4',
          ),
          languageCode: 'en',
          onProgress: stages.add,
        ),
        throwsA(isA<MealPhotoClarificationRequired>()),
      );
      expect(stages, [
        MealPhotoProposalStage.recognizing,
        MealPhotoProposalStage.validating,
      ]);
    },
  );
}
