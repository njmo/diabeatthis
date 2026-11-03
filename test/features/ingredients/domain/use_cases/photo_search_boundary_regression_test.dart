import 'package:diabeatthis/features/ingredients/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/ingredients/data/parsers/ingredient_photo_search_result_parser.dart';
import 'package:diabeatthis/features/ingredients/domain/use_cases/search_ingredient_from_photo_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/regression/scripted_ingredient_photo_search_client.dart';
import '../../../../helpers/regression/scripted_read.dart';

void main() {
  test('missing required photo cannot invoke a model', () async {
    final response = ScriptedRead<String>('photo model', []);
    final useCase = SearchIngredientFromPhotoUseCase(
      client: ScriptedIngredientPhotoSearchClient(response),
      parser: const IngredientPhotoSearchResultParser(),
    );
    await expectLater(
      useCase(const IngredientPhotoScanInput()),
      throwsStateError,
    );
    response.verifyComplete();
  });
  for (final raw in [
    '{"names":[" Rice ","rice","POTATO"],"brand":" BRAND "}',
    'not json',
  ]) {
    test(
      'photo search forwards only supplied inputs and validates response: $raw',
      () async {
        final response = ScriptedRead<String>('photo model', [
          (arguments: ['front.jpg', null], respond: () => raw),
        ]);
        final useCase = SearchIngredientFromPhotoUseCase(
          client: ScriptedIngredientPhotoSearchClient(response),
          parser: const IngredientPhotoSearchResultParser(),
        );
        final result = useCase(
          const IngredientPhotoScanInput(frontPhotoPath: 'front.jpg'),
        );
        if (raw == 'not json') {
          await expectLater(result, throwsFormatException);
        } else {
          final parsed = await result;
          expect(parsed.names, ['rice', 'potato']);
          expect(parsed.brand, 'brand');
        }
        response.verifyComplete();
      },
    );
  }
}
