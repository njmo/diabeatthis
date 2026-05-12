import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../clients/debug_ingredient_photo_scan_client.dart';

part 'debug_ingredient_photo_scan_provider.g.dart';

@riverpod
class DebugIngredientPhotoScanScenarioController
    extends _$DebugIngredientPhotoScanScenarioController {
  @override
  DebugIngredientPhotoScanScenario build() {
    return DebugIngredientPhotoScanScenario.recognized;
  }

  void setScenario(DebugIngredientPhotoScanScenario scenario) {
    state = scenario;
  }
}
