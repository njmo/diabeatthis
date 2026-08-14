import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ingredient_barcode_scan_feedback_controller.g.dart';

@riverpod
class IngredientBarcodeScanFeedback extends _$IngredientBarcodeScanFeedback {
  @override
  String? build() {
    return null;
  }

  void show(String message) {
    state = message;
  }
}
