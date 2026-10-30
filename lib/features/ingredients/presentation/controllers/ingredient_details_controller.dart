import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/storage/local_image_edit_session.dart';
import '../../../../common/storage/local_image_store_provider.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/domain/use_cases/load_ingredient_details_use_case.dart';
import '../../data/domain/use_cases/update_ingredient_details_use_case.dart';
import '../../data/mappers/ingredient_details_mapper.dart';
import '../../data/models/ingredient_details_data.dart';
import '../../data/providers/ingredient_provider.dart';
import '../models/ingredient_page_state.dart';

part 'ingredient_details_controller.g.dart';

@riverpod
class IngredientDetailsControllerNotifier
    extends _$IngredientDetailsControllerNotifier {
  LocalImageEditSession? _imageSession;
  void Function(String)? onIconSelected;

  @override
  Future<IngredientPageState> build(int ingredientId) async {
    ref.onDispose(() {
      final images = _imageSession;
      if (images != null) unawaited(images.discard());
    });
    final useCase = ref.read(loadIngredientDetailsUseCaseProvider);
    final data = await useCase.call(ingredientId);

    return IngredientPageState(data: data);
  }

  void startEditing() {
    final current = state.asData?.value;
    if (current == null || current.isSaving || current.isEditing) {
      return;
    }

    final db = ref.read(databaseProvider);
    final images = LocalImageEditSession(
      store: ref.read(localImageStoreProvider),
      isInUse: (path) async =>
          await (db.select(db.ingredient)
                ..where((row) => row.iconAssetPath.equals(path))
                ..limit(1))
              .getSingleOrNull() !=
          null,
    );
    _imageSession = images;
    ref
        .read(ingredientDraftProvider.notifier)
        .overrideDraft(current.data.ingredient.toDraft());
    onIconSelected = (path) {
      images.track(path);
      if (!ref.mounted ||
          !identical(images, _imageSession) ||
          state.asData?.value.isEditing != true) {
        unawaited(images.discard());
        return;
      }
      final draft = ref.read(ingredientDraftProvider);
      ref
          .read(ingredientDraftProvider.notifier)
          .overrideDraft(draft.copyWith(iconAssetPath: path));
    };
    ref.invalidate(ingredientFormKeyProvider);
    state = AsyncData(current.copyWith(isEditing: true));
  }

  Future<void> cancelEditing() async {
    final current = state.asData?.value;
    if (current == null || current.isSaving) {
      return;
    }

    if (current.isEditing) {
      ref
          .read(ingredientDraftProvider.notifier)
          .overrideDraft(current.data.ingredient.toDraft());
    }
    state = AsyncData(current.copyWith(isEditing: false));
    await _imageSession?.discard();
  }

  Future<void> save() async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(isSaving: true));

    try {
      final ingredient = ref.read(ingredientDraftProvider);
      final updateUseCase = ref.read(updateIngredientDetailsUseCaseProvider);
      final images = _imageSession;
      if (images == null) {
        await updateUseCase.call(ingredient);
      } else {
        await images.save(() => updateUseCase.call(ingredient));
        await images.cleanup();
      }
      if (!ref.mounted) return;

      final loadUseCase = ref.read(loadIngredientDetailsUseCaseProvider);
      final data = await loadUseCase.call(ingredientId);
      if (!ref.mounted) return;
      ref.invalidate(ingredientsByQueryProvider);
      ref.invalidate(latestIngredientsProvider);
      ref.invalidate(ingredientByIdProvider(ingredientId));
      state = AsyncData(IngredientPageState(data: data));
    } catch (_) {
      if (ref.mounted) state = AsyncData(current.copyWith(isSaving: false));
      rethrow;
    }
  }

  Future<void> updatePortionAmount({
    required int portionId,
    required double gramsPerPortion,
  }) async {
    final current = state.requireValue;
    if (current.isSaving) {
      return;
    }

    state = AsyncData(current.copyWith(isSaving: true));

    try {
      final updateUseCase = ref.read(updateIngredientDetailsUseCaseProvider);
      await updateUseCase.updatePortionAmount(
        ingredientId: ingredientId,
        portionId: portionId,
        gramsPerPortion: gramsPerPortion,
      );

      state = AsyncData(
        current.copyWith(
          data: _updatedPortionData(
            current.data,
            portionId: portionId,
            gramsPerPortion: gramsPerPortion,
          ),
          isSaving: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isSaving: false));
      rethrow;
    }
  }

  IngredientDetailsData _updatedPortionData(
    IngredientDetailsData data, {
    required int portionId,
    required double gramsPerPortion,
  }) {
    return data.copyWith(
      portions: [
        for (final portion in data.portions)
          if (portion.portionId == portionId)
            portion.copyWith(gramsPerPortion: gramsPerPortion)
          else
            portion,
      ],
    );
  }
}
