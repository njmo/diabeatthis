import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../presentation/details/ingredient_details_view.dart';
import '../../presentation/details/ingredient_preview_controller.dart';
import 'models/family_ingredient_details.dart';

/// Standalone catalog preview. Child-owned records use the scoped record page.
class FamilyIngredientDetailsDialog extends StatelessWidget {
  const FamilyIngredientDetailsDialog({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.lang.ingredientDetailsTitle),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonLabel,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: IngredientDetailsView(
        controller: CaregiverIngredientPreviewController(
          FamilyIngredientDetails.fromPayload(data),
          onOpenMeal: (_) {},
          showUsages: false,
          showHistory: false,
          showPortions: false,
        ),
      ),
    ),
  );
}
