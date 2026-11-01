import 'dart:io';
import 'dart:typed_data';

import 'package:diabeatthis/common/storage/local_image_store.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/update_quick_low_treatment_icon_use_case.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late Directory folder;
  late LocalImageStore store;
  late UpdateQuickLowTreatmentIconUseCase update;
  late int ingredientId;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    folder = await Directory.systemTemp.createTemp('quick-icon-update');
    store = LocalImageStore(directory: () async => folder);
    update = UpdateQuickLowTreatmentIconUseCase(db, store);
    ingredientId = await db
        .into(db.ingredient)
        .insert(
          IngredientCompanion.insert(
            name: 'Banana',
            carbsPer100g: 20,
            fatPer100g: 1,
            fiberPer100g: 2,
            proteinPer100g: 3,
            nutritionConfidence: 0.5,
          ),
        );
    for (var slot = 1; slot <= 2; slot++) {
      await db
          .into(db.quickLowTreatmentItem)
          .insert(
            QuickLowTreatmentItemCompanion.insert(
              name: 'Shortcut $slot',
              ingredientId: ingredientId,
              amount: slot.toDouble(),
              sortOrder: Value(slot),
            ),
          );
    }
  });
  tearDown(() async {
    await db.close();
    await folder.delete(recursive: true);
  });

  test(
    'ingredient icon is shared by its shortcuts without changing nutrition or amounts',
    () async {
      await update.call(
        ingredientId: ingredientId,
        path: 'assets/icons/food/banana.png',
      );
      final items = await db.quickLowTreatmentItemDao
          .getQuickLowTreatmentItems();
      expect(
        items.map((item) => item.ingredient.iconAssetPath),
        everyElement('assets/icons/food/banana.png'),
      );
      expect(items.map((item) => item.amount), [1, 2]);
      final ingredient = await db.ingredientDao.getIngredientById(ingredientId);
      expect(ingredient.carbsPer100g, 20);
      expect(ingredient.nutritionConfidence, 0.5);
      expect(
        await db.ingredientDao.getIngredientStatusHistory(ingredientId),
        isEmpty,
      );
    },
  );

  test('a successfully assigned generated image is retained', () async {
    final generated = await store.savePng(Uint8List.fromList([1]));
    await update.call(ingredientId: ingredientId, path: generated.path);
    expect(await generated.file.exists(), isTrue);
    expect(
      (await db.ingredientDao.getIngredientById(ingredientId)).iconAssetPath,
      generated.path,
    );
  });

  test('failed assignment cleans up an unreferenced generated image', () async {
    final generated = await store.savePng(Uint8List.fromList([1]));
    await expectLater(
      update.call(ingredientId: ingredientId + 100, path: generated.path),
      throwsStateError,
    );
    expect(await generated.file.exists(), isFalse);
  });

  test(
    'abandoned selection preserves images already used by an ingredient',
    () async {
      final generated = await store.savePng(Uint8List.fromList([1]));
      await update.call(ingredientId: ingredientId, path: generated.path);
      await update.discard(generated.path);
      expect(await generated.file.exists(), isTrue);
    },
  );
}
