import 'package:diabeatthis/features/ingredients/data/clients/ingredient_photo_search_client.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_photo_scan_input.dart';

import 'scripted_read.dart';

class ScriptedIngredientPhotoSearchClient
    implements IngredientPhotoSearchClient {
  final ScriptedRead<String> response;
  ScriptedIngredientPhotoSearchClient(this.response);

  @override
  Future<String> search(IngredientPhotoScanInput input) =>
      response([input.frontPhotoPath, input.nutritionLabelPhotoPath]);
}
