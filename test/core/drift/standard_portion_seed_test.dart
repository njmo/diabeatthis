import 'dart:io';

import 'package:diabeatthis/common/l10n/generated/app_localizations_en.dart';
import 'package:diabeatthis/common/l10n/generated/app_localizations_pl.dart';
import 'package:diabeatthis/common/portions/standard_portion_names.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/seed/seed_standard_portions.dart';
import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fresh database has one reusable piece name without an invented ingredient weight',
    () async {
      final database = DatabaseImpl.withStandardPortions(
        NativeDatabase.memory(),
      );
      addTearDown(database.close);
      expect(await database.select(database.portion).get(), hasLength(1));
      await seedStandardPortions(database);

      final pieces = await database.portionDao.getPortionsByQuery('sztuka');
      expect(pieces, hasLength(1));
      expect(pieces.single.name, standardPiecePortionName);
      expect(pieces.single.unitHint, standardPortionWeightUnit);
      expect(await database.select(database.ingredientPortions).get(), isEmpty);
      expect(await database.select(database.ingredient).get(), isEmpty);
      expect(
        localizedPortionName(pieces.single.name, AppLocalizationsPl()),
        'sztuka',
      );
      expect(
        localizedPortionName(pieces.single.name, AppLocalizationsEn()),
        'piece',
      );
    },
  );

  test(
    'opening an existing database keeps its localized piece and custom weight unit',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'standard-portion-seed-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final previous = UnseededPortionDatabase(NativeDatabase(file));
      await previous.customStatement(
        "INSERT INTO portion(name, unit_hint) VALUES ('sztuka', 'g')",
      );
      await previous.close();

      final reopened = DatabaseImpl.withStandardPortions(NativeDatabase(file));
      await seedStandardPortions(reopened);
      final portions = await reopened.select(reopened.portion).get();
      expect(portions, hasLength(1));
      expect(portions.single.name, 'sztuka');
      expect(
        await reopened.portionDao.getPortionsByQuery('piece'),
        hasLength(1),
      );
      await reopened.close();

      final again = DatabaseImpl.withStandardPortions(NativeDatabase(file));
      addTearDown(again.close);
      await seedStandardPortions(again);
      expect(await again.select(again.portion).get(), hasLength(1));
    },
  );

  test(
    'existing unseeded installations receive the standard name idempotently',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'existing-portion-seed-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final previous = UnseededPortionDatabase(NativeDatabase(file));
      await previous.customStatement(
        "INSERT INTO portion(name, unit_hint) VALUES ('Bowl', 'g')",
      );
      await previous.close();

      final reopened = DatabaseImpl.withStandardPortions(NativeDatabase(file));
      addTearDown(reopened.close);
      await seedStandardPortions(reopened);
      await seedStandardPortions(reopened);
      expect(await reopened.select(reopened.portion).get(), hasLength(2));
      expect(await reopened.portionDao.getPortionsByQuery('szt'), hasLength(1));
      expect(await reopened.portionDao.getPortionsByQuery('pie'), hasLength(1));
      expect(
        await reopened.portionDao.getPortionsByQuery('Bowl'),
        hasLength(1),
      );
    },
  );

  test(
    'aliases preserve the assigned and unassigned ingredient boundary',
    () async {
      final database = DatabaseImpl(NativeDatabase.memory());
      addTearDown(database.close);
      await seedStandardPortions(database);
      await database.customStatement('''INSERT INTO ingredient
      (id,name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,nutrition_confidence)
      VALUES (101,'Apple',12,0.2,2,0.3,0.75), (102,'Pear',13,0.1,3,0.4,0.5)''');
      final piece = (await database.portionDao.getPortionsByQuery(
        'piece',
      )).single;
      await database.insertIngredientPortion(101, piece.id, 150);

      expect(
        await database.portionDao.getPortionsForIngredientByQuery(
          101,
          'sztuka',
        ),
        hasLength(1),
      );
      expect(
        await database.portionDao.getUnassignedPortionsForIngredientByQuery(
          101,
          'sztuka',
        ),
        isEmpty,
      );
      expect(
        await database.portionDao.getPortionsForIngredientByQuery(
          102,
          'sztuka',
        ),
        isEmpty,
      );
      expect(
        await database.portionDao.getUnassignedPortionsForIngredientByQuery(
          102,
          'sztuka',
        ),
        hasLength(1),
      );
      expect(await database.portionDao.getGramsPerPortion(101, piece.id), 150);
    },
  );
}

class UnseededPortionDatabase extends DatabaseImpl {
  UnseededPortionDatabase(super.executor);

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());
}
