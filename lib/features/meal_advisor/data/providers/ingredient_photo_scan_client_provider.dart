import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/llm/providers/local_llm_client_provider.dart';
import '../clients/debug_ingredient_photo_scan_client.dart';
import '../clients/ingredient_photo_scan_client.dart';
import '../clients/local_llm_ingredient_photo_scan_client.dart';
import 'debug_ingredient_photo_scan_provider.dart';

part 'ingredient_photo_scan_client_provider.g.dart';

enum IngredientPhotoScanClientMode { debug, localLlm }

@riverpod
class IngredientPhotoScanClientModeController
    extends _$IngredientPhotoScanClientModeController {
  @override
  IngredientPhotoScanClientMode build() {
    return IngredientPhotoScanClientMode.debug;
  }

  void setMode(IngredientPhotoScanClientMode mode) {
    state = mode;
  }
}

@riverpod
IngredientPhotoScanClient ingredientPhotoScanClient(Ref ref) {
  final mode = ref.watch(ingredientPhotoScanClientModeControllerProvider);
  return switch (mode) {
    IngredientPhotoScanClientMode.debug => DebugIngredientPhotoScanClient(
      scenario: ref.watch(debugIngredientPhotoScanScenarioControllerProvider),
    ),
    IngredientPhotoScanClientMode.localLlm => LocalLlmIngredientPhotoScanClient(
      llmClient: ref.watch(localLlmClientProvider),
    ),
  };
}
