import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_provider.dart';
import 'package:diabeatthis/features/meal_photo/data/save_meal_draft_photo_writer.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/save_meal_draft_use_case.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class PhotoWriterIconClient implements LocalLlmClient {
  int calls = 0;
  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    calls++;
    return const LocalLlmResponse(text: '{}');
  }
}

final photoTestWriterProvider = Provider<SaveMealDraftPhotoWriter>(
  (ref) => SaveMealDraftPhotoWriter(
    saveMealDraft: SaveMealDraftUseCase(ref),
    language: () => lang,
  ),
);

void main() {
  for (final rollback in [false, true]) {
    test(
      'photo writer does not launch background writes before outer transaction ${rollback ? "rollback" : "commit"}',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final icons = PhotoWriterIconClient();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            ingredientIconClientProvider.overrideWithValue(icons),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        final draft = MealDraft(
          name: 'Photo meal',
          category: MealCategory.snack,
          plannedAt: DateTime(2026, 11, 3),
          status: 'planned',
          mealIngredients: const [
            MealIngredientsDraft(
              ingredient: IngredientDraft.draft(
                name: 'Rice',
                carbsPer100g: 25,
                fatPer100g: 1,
                fiberPer100g: 1,
                proteinPer100g: 2,
                nutritionConfidence: .6,
                isReference: false,
              ),
              ingredientPortion: IngredientPortionDraft(
                portion: PortionSelection.empty(),
                amount: 1,
              ),
              amount: 100,
              recordedGramsPerAmount: 1,
              quantityConfidence: .5,
              entryType: 'planned',
              consumedAmount: null,
              consumedConfidence: null,
            ),
          ],
        );
        final operation = db.transaction(() async {
          await container.read(photoTestWriterProvider).write(draft);
          expect(icons.calls, 0);
          if (rollback) throw StateError('Outer write failed');
        });
        if (rollback) {
          await expectLater(operation, throwsStateError);
        } else {
          await operation;
        }
        await Future<void>.delayed(Duration.zero);
        expect(icons.calls, 0);
        expect((await db.select(db.meal).get()).length, rollback ? 0 : 1);
        expect((await db.select(db.ingredient).get()).length, rollback ? 0 : 1);
      },
    );
  }
}
