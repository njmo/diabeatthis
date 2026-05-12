import '../models/ingredient_photo_scan_input.dart';

abstract interface class IngredientPhotoSearchClient {
  Future<String> search(IngredientPhotoScanInput input);
}
