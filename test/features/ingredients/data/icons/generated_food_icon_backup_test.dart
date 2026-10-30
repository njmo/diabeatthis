import 'dart:io';

import 'package:diabeatthis/common/storage/local_image_store.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/ingredients/data/icons/food_icon_generation_service.dart';
import 'package:diabeatthis/features/settings/data/database_backup_scope.dart';
import 'package:diabeatthis/features/settings/data/database_backup_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'generated image is included in backup and restored on a different phone directory',
    () async {
      final source = await Directory.systemTemp.createTemp('food-source-');
      final destination = await Directory.systemTemp.createTemp(
        'food-destination-',
      );
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        await source.delete(recursive: true);
        await destination.delete(recursive: true);
      });
      final image = await FoodIconGenerationService(
        generate: (_) =>
            File('assets/icons/wicked_food/flour-tortillas.webp').readAsBytes(),
        directory: () async => source,
      ).run('Tortilla');
      expect(LocalImageStore.contains(image.path), isTrue);
      await db
          .into(db.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'Tortilla',
              carbsPer100g: 50,
              fatPer100g: 5,
              fiberPer100g: 2,
              proteinPer100g: 8,
              nutritionConfidence: 1,
              iconAssetPath: Value(image.path),
            ),
          );
      final backup = await DatabaseBackupService(
        db,
        imageStore: LocalImageStore(directory: () async => source),
      ).exportToJson(DatabaseBackupScope.core);
      expect((backup['ingredientImages'] as Map).keys, contains(image.path));
      final targetStore = LocalImageStore(directory: () async => destination);
      await DatabaseBackupService(
        db,
        imageStore: targetStore,
      ).importFromJson(backup);
      final restored = await db.select(db.ingredient).getSingle();
      expect(restored.iconAssetPath, isNot(image.path));
      final file = await targetStore.resolve(restored.iconAssetPath!);
      expect(await file.readAsBytes(), await image.file.readAsBytes());
    },
  );

  test('invalid image paths cannot read outside application image storage', () {
    for (final path in [
      '/etc/passwd',
      'local-images/generated/../../file.png',
      'assets/icons/food/apple.png',
      'local-images/generated/file.jpg',
    ]) {
      expect(LocalImageStore.contains(path), isFalse);
    }
  });
}
