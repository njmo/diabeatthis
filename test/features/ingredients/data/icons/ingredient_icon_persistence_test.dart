import 'dart:async';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/mappers/ingredient_drift_mapper.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_provider.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_service.dart';
import 'package:diabeatthis/features/ingredients/data/persistence/insert_ingredient_draft.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingIconClient implements LocalLlmClient {
  final response = Completer<LocalLlmResponse>();
  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) => response.future;
}

const draft = IngredientDraft.draft(
  name: 'Burger',
  carbsPer100g: 20,
  fatPer100g: 10,
  fiberPer100g: 1,
  proteinPer100g: 10,
  nutritionConfidence: 0.5,
  isReference: true,
);

void main() {
  late DatabaseImpl db;
  setUp(() => db = DatabaseImpl(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'insert and read retain the full asset path for a reference dish',
    () async {
      final saved = await insertIngredientDraft(
        db,
        draft.copyWith(iconAssetPath: 'assets/icons/food/hamburger.png'),
      );
      final stored = await db.ingredientDao.getIngredientById(saved.id);
      expect(stored.iconAssetPath, 'assets/icons/food/hamburger.png');
      expect(stored.toDomain().toJson()['iconAssetPath'], stored.iconAssetPath);
    },
  );

  test(
    'late classification fills an already saved ingredient without changing nutrition',
    () async {
      final saved = await insertIngredientDraft(db, draft);
      final client = PendingIconClient();
      final job = persistIngredientIcon(
        db,
        IngredientIconService(client: client),
        saved.id,
        saved.name,
        saved.brand,
      );
      client.response.complete(
        const LocalLlmResponse(text: '{"icon":"hamburger"}'),
      );
      await job;
      final stored = await db.ingredientDao.getIngredientById(saved.id);
      expect(stored.iconAssetPath, 'assets/icons/food/hamburger.png');
      expect(stored.carbsPer100g, saved.carbsPer100g);
      expect(await db.select(db.ingredientStatusHistory).get(), isEmpty);
    },
  );

  for (final changeName in [true, false]) {
    test(
      'late classification cannot overwrite ${changeName ? 'a renamed ingredient' : 'an assigned icon'}',
      () async {
        final saved = await insertIngredientDraft(db, draft);
        final client = PendingIconClient();
        final job = persistIngredientIcon(
          db,
          IngredientIconService(client: client),
          saved.id,
          saved.name,
          saved.brand,
        );
        await (db.update(
          db.ingredient,
        )..where((row) => row.id.equals(saved.id))).write(
          changeName
              ? const IngredientCompanion(name: Value('Soup'))
              : const IngredientCompanion(
                  iconAssetPath: Value('assets/icons/food/pizza.png'),
                ),
        );
        client.response.complete(
          const LocalLlmResponse(text: '{"icon":"hamburger"}'),
        );
        await job;
        final stored = await db.ingredientDao.getIngredientById(saved.id);
        expect(
          stored.iconAssetPath,
          changeName ? isNull : 'assets/icons/food/pizza.png',
        );
      },
    );
  }
}
