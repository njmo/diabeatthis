import '../models/ingredient_photo_scan_input.dart';

abstract interface class IngredientPhotoScanClient {
  Future<String> scan(IngredientPhotoScanInput input);
}
