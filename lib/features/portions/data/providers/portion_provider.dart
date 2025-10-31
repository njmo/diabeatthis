import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/portion.dart' as domain;
import '../../../../core/drift/mappers/portion_drift_mapper.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../drafts/portion_draft.dart';

part 'portion_provider.g.dart';

@riverpod
Stream<List<domain.Portion>> portionsStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.portionDao.getAllPortions().watch().map((e) => e.toDomainList());
}

@riverpod
Future<List<domain.Portion>> portions(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final portions = await db.portionDao.getAllPortions().get();
  return portions.map((e) => e.toDomain()).toList();
}

@riverpod
Future<List<domain.Portion>> portionsByQuery(Ref ref, String query) async {
  final db = ref.watch(databaseProvider);
  final portions = await db.portionDao.searchPortionsByName(query).get();
  return portions.map((e) => e.toDomain()).toList();
}

@riverpod
Future<List<domain.Portion>> portionsByIngredient(
  Ref ref,
  IngredientSelection ingredient,
) async {
  final db = ref.watch(databaseProvider);
  final portions = await db.portionDao.getPortionsForIngredient(
    ingredient.map(draft: (draft) => 0, existing: (existing) => existing.id!),
  );
  return portions.map((e) => e.toDomain()).toList();
}

@riverpod
Future<List<domain.Portion>> portionsNotInIngredient(
  Ref ref,
  IngredientSelection ingredient,
) async {
  final db = ref.watch(databaseProvider);
  final portions = await db.portionDao.getUnassignedPortionsForIngredient(
    ingredient.map(draft: (draft) => 0, existing: (existing) => existing.id!),
  );
  return portions.map((e) => e.toDomain()).toList();
}

@riverpod
Future<int?> gramsPerPortion(
    Ref ref,
    IngredientSelection ingredient,
    PortionSelection portion,
    ) async {
  final db = ref.watch(databaseProvider);
  final grams = await db.portionDao.getGramsPerPortion(
    ingredient.map(draft: (draft) => 0, existing: (existing) => existing.id!),
    portion.map(draft: (draft) => 0, existing: (existing) => existing.id),
  );
  return grams;
}

@riverpod
Future<void> insertPortion(Ref ref, domain.Portion portion) async {
  final db = ref.watch(databaseProvider);
  await db.into(db.portion).insert(portion.toCompanion());
}

@riverpod
class PortionDraft extends _$PortionDraft {
  @override
  PortionSelection build() {
    return PortionSelection.draft(name: '', unitHint: '');
  }

  void setUnitHint(String value) => state = state.copyWith(unitHint: value);
  void setName(String value) => state = state.copyWith(name: value);
}
