import '../../../../common/utils/normalize_optional_text.dart';
import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/mappers/ingredient_drift_mapper.dart';
import '../drafts/ingredient_draft.dart';
import '../drafts/ingredient_draft_validation.dart';
import '../mappers/ingredient_draft_mapper.dart';

Future<domain.Ingredient> insertIngredientDraft(
  DatabaseImpl db,
  IngredientDraft ingredient,
) async {
  return ingredient.map(
    draft: (draft) async {
      final name = draft.name.trim();
      if (name.isEmpty) {
        throw ArgumentError('Ingredient name cannot be empty');
      }
      final fiberPer100g = draft.isReference ? 0.0 : draft.fiberPer100g;
      final ingredient = draft.copyWith(
        name: name,
        brand: normalizeOptionalText(draft.brand),
        fiberPer100g: fiberPer100g,
        barcode: draft.normalizedBarcode,
      );
      ingredient.validateMacroRanges();
      ingredient.validateBarcode();

      final value = await db
          .into(db.ingredient)
          .insertReturningOrNull(ingredient.toCompanion());
      if (value != null) {
        return value.toDomain();
      } else {
        throw Exception('Could not insert ingredient');
      }
    },
    existing: (_) => ingredient.toDomain(),
  );
}
