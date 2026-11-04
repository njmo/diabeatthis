import 'package:diabeatthis/common/ingredient_catalog/ingredient_match_score.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_candidate.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/find_meal_photo_product_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';
import 'meal_photo_proposal_test.dart' as fixtures;

class LocalizedSauceCandidates extends TestPhotoCandidates {
  @override
  Future<List<MealPhotoCandidate>> search(
    String query, {
    required String languageCode,
    int limit = 8,
  }) async {
    queries.add(query);
    return query == 'Sos ziołowy'
        ? [
            MealPhotoCandidate(
              identity: fixtures.candidate.identity,
              name: 'Sos ziołowy',
              nutritionPer100g: fixtures.candidate.nutritionPer100g,
            ),
          ]
        : [];
  }
}

void main() {
  test(
    'automatic lookup tries the same localized name used by the picker',
    () async {
      final row = fixtures.component('sauce', kind: 'proposed_reference')
        ..['name'] = 'Sos ziołowy'
        ..['search_query'] = 'herb sauce prepared';
      final item = const MealPhotoProposalParser()
          .parse(fixtures.proposal(item: row))
          .itemized
          .single;
      final candidates = LocalizedSauceCandidates();
      final match = await FindMealPhotoProductUseCase(candidates)(
        item,
        languageCode: 'pl',
      );
      expect(candidates.queries, ['herb sauce prepared', 'Sos ziołowy']);
      expect(match?.name, 'Sos ziołowy');
    },
  );
  test('English canonical names do not override an exact localized name', () {
    expect(
      ingredientNameMatchScore(
        'Sos ziołowy',
        'Sos ziołowy',
        'Sauce, herb, prepared',
      ),
      1,
    );
    expect(
      ingredientNameMatchScore('herb sauce', 'Sos ziołowy', 'Sauce, herb'),
      1,
    );
    expect(
      ingredientNameMatchScore(
        'Sos ziołowy',
        'Sos spaghetti',
        'Spaghetti sauce',
      ),
      0,
    );
  });
}
