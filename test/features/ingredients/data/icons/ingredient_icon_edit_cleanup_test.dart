import 'dart:io';
import 'dart:typed_data';

import 'package:diabeatthis/common/storage/local_image_store.dart';
import 'package:diabeatthis/common/storage/local_image_store_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_details_controller.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late LocalImageStore store;
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'ingredient-edit-cleanup',
    );
    store = LocalImageStore(directory: () async => directory);
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        localImageStoreProvider.overrideWithValue(store),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<int> insert({bool reference = false, String? path}) => db
      .into(db.ingredient)
      .insert(
        IngredientCompanion.insert(
          name: 'Jogurt',
          carbsPer100g: 12,
          fatPer100g: 3,
          fiberPer100g: 0,
          proteinPer100g: 5,
          nutritionConfidence: 0.5,
          isReference: Value(reference ? 1 : 0),
          iconAssetPath: Value(path),
        ),
      );

  Future<IngredientDetailsControllerNotifier> edit(int id) async {
    container.listen(ingredientDraftProvider, (_, _) {});
    container.listen(ingredientDetailsControllerProvider(id), (_, _) {});
    await container.read(ingredientDetailsControllerProvider(id).future);
    final controller = container.read(
      ingredientDetailsControllerProvider(id).notifier,
    );
    controller.startEditing();
    return controller;
  }

  for (final reference in [false, true]) {
    test(
      'cancel deletes replaced generated images and preserves the saved icon (reference=$reference)',
      () async {
        final original = await store.savePng(Uint8List.fromList([1]));
        final first = await store.savePng(Uint8List.fromList([2]));
        final second = await store.savePng(Uint8List.fromList([3]));
        final id = await insert(reference: reference, path: original.path);
        final controller = await edit(id);
        controller.onIconSelected!(first.path);
        controller.onIconSelected!(second.path);
        await controller.cancelEditing();
        expect(await original.file.exists(), isTrue);
        expect(await first.file.exists(), isFalse);
        expect(await second.file.exists(), isFalse);
        expect(
          (await db.ingredientDao.getIngredientById(id)).iconAssetPath,
          original.path,
        );
      },
    );

    test(
      'save keeps the selected image and deletes superseded selections (reference=$reference)',
      () async {
        final first = await store.savePng(Uint8List.fromList([1]));
        final second = await store.savePng(Uint8List.fromList([2]));
        final id = await insert(reference: reference);
        final controller = await edit(id);
        controller.onIconSelected!(first.path);
        controller.onIconSelected!(second.path);
        await controller.save();
        expect(await first.file.exists(), isFalse);
        expect(await second.file.exists(), isTrue);
        expect(
          (await db.ingredientDao.getIngredientById(id)).iconAssetPath,
          second.path,
        );
        await controller.cancelEditing();
        expect(await second.file.exists(), isTrue);
      },
    );
  }

  test('cancel keeps an image used by another ingredient', () async {
    final shared = await store.savePng(Uint8List.fromList([1]));
    await insert(path: shared.path);
    final controller = await edit(await insert());
    controller.onIconSelected!(shared.path);
    await controller.cancelEditing();
    expect(await shared.file.exists(), isTrue);
  });

  test('failed save allows retry with the same generated image', () async {
    final selected = await store.savePng(Uint8List.fromList([1]));
    final id = await insert();
    final controller = await edit(id);
    controller.onIconSelected!(selected.path);
    container.read(ingredientDraftProvider.notifier).setName('');
    await expectLater(controller.save(), throwsArgumentError);
    expect(await selected.file.exists(), isTrue);
    container.read(ingredientDraftProvider.notifier).setName('Jogurt');
    await controller.save();
    expect(
      (await db.ingredientDao.getIngredientById(id)).iconAssetPath,
      selected.path,
    );
    expect(await selected.file.exists(), isTrue);
  });

  test(
    'a picker result arriving after cancel does not modify the draft',
    () async {
      final selected = await store.savePng(Uint8List.fromList([1]));
      final controller = await edit(await insert());
      final select = controller.onIconSelected!;
      await controller.cancelEditing();
      select(selected.path);
      // Also awaits the best-effort cleanup triggered by the abandoned result.
      await controller.cancelEditing();
      expect(container.read(ingredientDraftProvider).iconAssetPath, isNull);
      expect(await selected.file.exists(), isFalse);
    },
  );
}
