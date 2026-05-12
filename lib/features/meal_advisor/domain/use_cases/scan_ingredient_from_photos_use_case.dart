import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/clients/ingredient_photo_scan_client.dart';
import '../../data/models/ingredient_photo_scan_input.dart';
import '../../data/models/ingredient_scan_result.dart';
import '../../data/parsers/ingredient_scan_result_parser.dart';
import '../../data/providers/ingredient_photo_scan_client_provider.dart';
import '../services/ingredient_scan_result_validator.dart';

part 'scan_ingredient_from_photos_use_case.g.dart';

@riverpod
ScanIngredientFromPhotosUseCase scanIngredientFromPhotosUseCase(Ref ref) {
  return ScanIngredientFromPhotosUseCase(
    client: ref.watch(ingredientPhotoScanClientProvider),
    parser: const IngredientScanResultParser(),
    validator: const IngredientScanResultValidator(),
  );
}

class ScanIngredientFromPhotosUseCase {
  final IngredientPhotoScanClient client;
  final IngredientScanResultParser parser;
  final IngredientScanResultValidator validator;

  const ScanIngredientFromPhotosUseCase({
    required this.client,
    required this.parser,
    required this.validator,
  });

  Future<IngredientScanResult> call(IngredientPhotoScanInput input) async {
    if (!input.hasRequiredPhotos) {
      throw StateError(
        'Ingredient scan requires front and nutrition label photos.',
      );
    }

    final response = await client.scan(input);
    return validator.validate(parser.parse(response));
  }
}
