import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/sheet_choice_tile.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../controllers/ingredient_barcode_lookup_controller.dart';
import '../controllers/ingredient_lookup_actions_controller.dart';

class IngredientCreationMethods extends ConsumerWidget {
  const IngredientCreationMethods({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final controller = ref.read(addMealIngredientStageProvider.notifier);
    final scanning = ref
        .watch(ingredientBarcodeLookupControllerProvider)
        .isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetChoiceTile(
          icon: Icons.add_a_photo_outlined,
          title: lang.ingredientCreatePhotos,
          subtitle: lang.ingredientCreatePhotosHint,
          onTap: scanning ? null : controller.startIngredientPhotoScan,
        ),
        const SizedBox(height: 10),
        SheetChoiceTile(
          icon: Icons.qr_code_scanner,
          title: scanning ? lang.commonLoading : lang.ingredientCreateCode,
          subtitle: lang.ingredientCreateCodeHint,
          onTap: scanning
              ? null
              : () => IngredientLookupActionsController(
                  ref,
                ).searchByCode(context),
        ),
        const SizedBox(height: 10),
        SheetChoiceTile(
          icon: Icons.restaurant_menu,
          title: lang.ingredientReferenceDishTitle,
          subtitle: lang.ingredientCreateReferenceHint,
          onTap: scanning ? null : controller.startReferenceIngredient,
        ),
        const SizedBox(height: 10),
        SheetChoiceTile(
          icon: Icons.edit_outlined,
          title: lang.ingredientCreateManual,
          subtitle: lang.ingredientCreateManualHint,
          onTap: scanning ? null : controller.startManualIngredient,
        ),
      ],
    );
  }
}
