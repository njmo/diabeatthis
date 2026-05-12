import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/clients/debug_ingredient_photo_scan_client.dart';
import '../../data/models/ingredient_scan_result.dart';
import '../../data/parsers/ingredient_scan_result_parser.dart';
import '../../data/providers/debug_ingredient_photo_scan_provider.dart';
import '../services/ingredient_scan_result_validator.dart';

part 'scan_ingredient_from_photos_use_case.g.dart';

@riverpod
ScanIngredientFromPhotosUseCase scanIngredientFromPhotosUseCase(Ref ref) {
  final scenario = ref.watch(
    debugIngredientPhotoScanScenarioControllerProvider,
  );
  return ScanIngredientFromPhotosUseCase(
    client: DebugIngredientPhotoScanClient(scenario: scenario),
    parser: const IngredientScanResultParser(),
    validator: const IngredientScanResultValidator(),
  );
}

class ScanIngredientFromPhotosUseCase {
  final DebugIngredientPhotoScanClient client;
  final IngredientScanResultParser parser;
  final IngredientScanResultValidator validator;

  const ScanIngredientFromPhotosUseCase({
    required this.client,
    required this.parser,
    required this.validator,
  });

  Future<IngredientScanResult> call() async {
    final response = await client.scan();
    return validator.validate(parser.parse(response));
  }
}
