import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/clients/ingredient_photo_search_client.dart';
import '../../data/models/ingredient_photo_scan_input.dart';
import '../../data/models/ingredient_photo_search_result.dart';
import '../../data/parsers/ingredient_photo_search_result_parser.dart';
import '../../data/providers/ingredient_photo_search_client_provider.dart';

part 'search_ingredient_from_photo_use_case.g.dart';

@riverpod
SearchIngredientFromPhotoUseCase searchIngredientFromPhotoUseCase(Ref ref) {
  return SearchIngredientFromPhotoUseCase(
    client: ref.watch(ingredientPhotoSearchClientProvider),
    parser: const IngredientPhotoSearchResultParser(),
  );
}

class SearchIngredientFromPhotoUseCase {
  final IngredientPhotoSearchClient client;
  final IngredientPhotoSearchResultParser parser;

  const SearchIngredientFromPhotoUseCase({
    required this.client,
    required this.parser,
  });

  Future<IngredientPhotoSearchResult> call(
    IngredientPhotoScanInput input,
  ) async {
    if (!input.hasFrontPhoto) {
      throw StateError('Ingredient photo search requires a front photo.');
    }

    final response = await client.search(input);
    return parser.parse(response);
  }
}
