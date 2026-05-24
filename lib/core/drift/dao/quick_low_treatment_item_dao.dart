import 'package:drift/drift.dart';

import '../../domain/model/quick_low_treatment_item.dart' as domain;
import '../database_impl.dart';
import '../mappers/ingredient_drift_mapper.dart';
import '../mappers/portion_drift_mapper.dart';

part 'quick_low_treatment_item_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/quick_low_treatment_item.drift'})
class QuickLowTreatmentItemDao extends DatabaseAccessor<DatabaseImpl>
    with _$QuickLowTreatmentItemDaoMixin {
  QuickLowTreatmentItemDao(super.db);

  Stream<List<domain.QuickLowTreatmentItem>> watchQuickLowTreatmentItems() {
    return _quickLowTreatmentItemsQuery().watch().map(_mapRows);
  }

  Future<List<domain.QuickLowTreatmentItem>> getQuickLowTreatmentItems() async {
    final rows = await _quickLowTreatmentItemsQuery().get();
    return _mapRows(rows);
  }

  Future<domain.QuickLowTreatmentItem> insertQuickLowTreatmentItem(
    QuickLowTreatmentItemCompanion item,
  ) async {
    final row = await into(db.quickLowTreatmentItem).insertReturning(item);
    return getQuickLowTreatmentItemById(row.id);
  }

  Future<domain.QuickLowTreatmentItem> updateQuickLowTreatmentItem(
    int id,
    QuickLowTreatmentItemCompanion item,
  ) async {
    final updatedRows = await (update(
      db.quickLowTreatmentItem,
    )..where((tbl) => tbl.id.equals(id))).writeReturning(item);
    if (updatedRows.isEmpty) {
      throw StateError('Quick low treatment item $id was not found');
    }
    return getQuickLowTreatmentItemById(updatedRows.single.id);
  }

  Future<void> updateQuickLowTreatmentItemSortOrder({
    required int id,
    required int sortOrder,
  }) async {
    final updatedRows =
        await (update(
          db.quickLowTreatmentItem,
        )..where((tbl) => tbl.id.equals(id))).writeReturning(
          QuickLowTreatmentItemCompanion(sortOrder: Value(sortOrder)),
        );
    if (updatedRows.isEmpty) {
      throw StateError('Quick low treatment item $id was not found');
    }
  }

  Future<void> deleteQuickLowTreatmentItem(int id) async {
    await (delete(
      db.quickLowTreatmentItem,
    )..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<domain.QuickLowTreatmentItem> getQuickLowTreatmentItemById(
    int id,
  ) async {
    final query = _quickLowTreatmentItemsQuery()
      ..where(db.quickLowTreatmentItem.id.equals(id));
    final row = await query.getSingle();
    return _mapRow(row);
  }

  JoinedSelectStatement<HasResultSet, dynamic> _quickLowTreatmentItemsQuery() {
    final q = db.quickLowTreatmentItem;
    final ip = db.ingredientPortions;

    return select(q).join([
      innerJoin(db.ingredient, db.ingredient.id.equalsExp(q.ingredientId)),
      leftOuterJoin(db.portion, db.portion.id.equalsExp(q.portionId)),
      leftOuterJoin(
        ip,
        ip.ingredientId.equalsExp(q.ingredientId) &
            ip.portionId.equalsExp(q.portionId),
      ),
    ])..orderBy([OrderingTerm.asc(q.sortOrder), OrderingTerm.asc(q.id)]);
  }

  List<domain.QuickLowTreatmentItem> _mapRows(List<TypedResult> rows) {
    return rows.map(_mapRow).toList(growable: false);
  }

  domain.QuickLowTreatmentItem _mapRow(TypedResult row) {
    final item = row.readTable(db.quickLowTreatmentItem);
    final ingredient = row.readTable(db.ingredient);
    final portion = row.readTableOrNull(db.portion);
    final ingredientPortion = row.readTableOrNull(db.ingredientPortions);

    return domain.QuickLowTreatmentItem(
      id: item.id,
      name: item.name,
      ingredient: ingredient.toDomain(),
      portion: portion?.toDomain(),
      amount: item.amount,
      sortOrder: item.sortOrder,
      gramsPerPortion: ingredientPortion?.gramsPerPortion,
    );
  }
}
