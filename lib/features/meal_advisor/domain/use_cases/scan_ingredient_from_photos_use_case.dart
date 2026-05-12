import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/clients/debug_ingredient_photo_scan_client.dart';
import '../../data/models/ingredient_scan_result.dart';
import '../../data/parsers/ingredient_scan_result_parser.dart';

part 'scan_ingredient_from_photos_use_case.g.dart';

@riverpod
ScanIngredientFromPhotosUseCase scanIngredientFromPhotosUseCase(Ref ref) {
  return const ScanIngredientFromPhotosUseCase(
    client: DebugIngredientPhotoScanClient(),
    parser: IngredientScanResultParser(),
  );
}

class ScanIngredientFromPhotosUseCase {
  final DebugIngredientPhotoScanClient client;
  final IngredientScanResultParser parser;

  const ScanIngredientFromPhotosUseCase({
    required this.client,
    required this.parser,
  });

  Future<IngredientScanResult> call() async {
    final response = await client.scan();
    return parser.parse(response);
  }
}
