import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'portion_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/portion.drift'})
class PortionDao extends DatabaseAccessor<DatabaseImpl> with _$PortionDaoMixin {
  PortionDao(super.db);

  Future<List<PortionData>> getPortionsForIngredientByQuery(int ingredientId, String queryStr) {
    final query = select(db.portion).join([
      innerJoin(
        db.ingredientPortions,
        db.ingredientPortions.portionId.equalsExp(portion.id),
      ),
    ])
      ..where(db.ingredientPortions.ingredientId.equals(ingredientId))
      ..where(db.portion.name.like('%$queryStr%'))
      ..limit(10);

    return query.map((row) => row.readTable(db.portion)).get();
  }

  Future<List<PortionData>> getUnassignedPortionsForIngredientByQuery(int ingredientId, String queryStr) {
    final query = select(db.portion).join([
      leftOuterJoin(
        db.ingredientPortions,
        db.ingredientPortions.portionId.equalsExp(portion.id) &
        db.ingredientPortions.ingredientId.equals(ingredientId),
      ),
    ])
      ..where(db.ingredientPortions.portionId.isNull())
      ..where(db.portion.name.like('%$queryStr%'))
      ..limit(10);

    return query.map((row) => row.readTable(db.portion)).get();
  }

  Future<PortionData> getPortionById(int id) {
    final query = select(db.portion)..where((tbl) => tbl.id.equals(id));

    return query.getSingle();
  }

  Future<double?> getGramsPerPortion(int ingredientId, int portionId) async {
    final query = select(db.ingredientPortions)
      ..where((tbl) =>
      tbl.ingredientId.equals(ingredientId) &
      tbl.portionId.equals(portionId),
      );

    final result = await query.getSingleOrNull();
    return result?.gramsPerPortion;
  }
}