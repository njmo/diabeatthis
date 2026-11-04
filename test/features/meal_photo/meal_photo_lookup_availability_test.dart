import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_candidate.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';

class EmptyPhotoCandidates extends TestPhotoCandidates {
  EmptyPhotoCandidates({this.fail = false});
  final bool fail;
  @override
  Future<List<MealPhotoCandidate>> search(
    String query, {
    required String languageCode,
    int limit = 8,
  }) async {
    if (fail) throw StateError('Catalog unavailable');
    return [];
  }
}

void main() {
  for (final fail in [false, true]) {
    test(
      'empty catalog and failed catalog remain distinct: failure=$fail',
      () async {
        final controller = MealPhotoController(
          propose: ProposeMealFromPhotoUseCase(
            client: TestPhotoClient(),
            candidates: EmptyPhotoCandidates(fail: fail),
          ),
          saver: TestPhotoSaver(),
        );
        addTearDown(controller.dispose);
        await controller.generate(
          const MealPhotoInput(mealPhotoPath: 'plate.jpg'),
          languageCode: 'en',
        );
        await controller.divideIntoIngredients(languageCode: 'en');
        expect(controller.state.step, MealPhotoStep.assignment);
        expect(controller.state.loading, isFalse);
        expect(controller.noProductMatches.contains('potatoes'), !fail);
        expect(controller.state.error, fail ? isA<StateError>() : isNull);
      },
    );
  }
}
