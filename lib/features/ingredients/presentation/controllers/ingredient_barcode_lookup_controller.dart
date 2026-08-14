import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/logger/logger.dart';
import '../../data/domain/use_cases/find_ingredient_by_barcode_use_case.dart';
import '../../data/domain/use_cases/find_matching_ingredient_for_scan_result_use_case.dart';
import '../../data/mappers/ingredient_scan_result_mapper.dart';
import '../../data/models/ingredient_scan_result.dart';
import '../../domain/use_cases/scan_ingredient_from_barcode_use_case.dart';
import '../models/ingredient_barcode_scan_outcome.dart';

part 'ingredient_barcode_lookup_controller.g.dart';

@riverpod
class IngredientBarcodeLookupController
    extends _$IngredientBarcodeLookupController
    with Logging {
  @override
  FutureOr<IngredientBarcodeScanOutcome?> build() {
    return null;
  }

  Future<IngredientBarcodeScanOutcome> scan(String barcode) async {
    state = const AsyncLoading();
    final findIngredientByBarcode = ref.read(
      findIngredientByBarcodeUseCaseProvider,
    );
    final scanIngredientFromBarcode = ref.read(
      scanIngredientFromBarcodeUseCaseProvider,
    );
    final findMatchingIngredient = ref.read(
      findMatchingIngredientForScanResultUseCaseProvider,
    );

    try {
      final localIngredient = await findIngredientByBarcode.call(barcode);
      if (localIngredient != null) {
        final outcome = IngredientBarcodeScanOutcome.existingIngredient(
          localIngredient,
        );
        state = AsyncData(outcome);
        return outcome;
      }

      final result = await scanIngredientFromBarcode.call(barcode);
      if (!result.needsRetake) {
        final matchingIngredient = await _findMatchingIngredientOrNull(
          useCase: findMatchingIngredient,
          result: result,
        );
        if (matchingIngredient != null) {
          final outcome = IngredientBarcodeScanOutcome.existingIngredient(
            matchingIngredient,
          );
          state = AsyncData(outcome);
          return outcome;
        }
      }

      final draft = result.hasUsableBarcodeDraftData
          ? result.toIngredientDraft()
          : null;
      final outcome = switch ((result.needsReview, draft)) {
        (true, final draft?) => IngredientBarcodeScanOutcome.needsReview(draft),
        (false, final draft?) => IngredientBarcodeScanOutcome.newDraft(draft),
        _ => const IngredientBarcodeScanOutcome.failed(null),
      };
      state = AsyncData(outcome);
      return outcome;
    } catch (error, stackTrace) {
      final outcome = IngredientBarcodeScanOutcome.failed(error);
      state = AsyncError(error, stackTrace);
      return outcome;
    }
  }

  Future<domain.Ingredient?> _findMatchingIngredientOrNull({
    required FindMatchingIngredientForScanResultUseCase useCase,
    required IngredientScanResult result,
  }) async {
    try {
      return await useCase.call(result);
    } catch (error) {
      logW(
        'Ingredient barcode local matching failed, continuing with Open Food Facts draft. error=$error',
      );
      return null;
    }
  }
}
