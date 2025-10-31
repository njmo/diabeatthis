import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'portion_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/portion.drift'})
class PortionDao extends DatabaseAccessor<DatabaseImpl> with _$PortionDaoMixin {
  PortionDao(super.db);

  Future<List<PortionData>> getPortionsForIngredient(int ingredientId) {
    final query = select(db.portion).join([
      innerJoin(
        db.ingredientPortions,
        db.ingredientPortions.portionId.equalsExp(portion.id),
      ),
    ])
      ..where(db.ingredientPortions.ingredientId.equals(ingredientId));

    return query.map((row) => row.readTable(db.portion)).get();
  }

  Future<List<PortionData>> getUnassignedPortionsForIngredient(int ingredientId) {
    final query = select(db.portion).join([
      leftOuterJoin(
        db.ingredientPortions,
        db.ingredientPortions.portionId.equalsExp(portion.id) &
        db.ingredientPortions.ingredientId.equals(ingredientId),
      ),
    ])
      ..where(db.ingredientPortions.portionId.isNull());

    return query.map((row) => row.readTable(db.portion)).get();
  }

  Future<int?> getGramsPerPortion(int ingredientId, int portionId) async {
    final query = select(db.ingredientPortions)
      ..where((tbl) =>
      tbl.ingredientId.equals(ingredientId) &
      tbl.portionId.equals(portionId),
      );

    final result = await query.getSingleOrNull();
    return result?.gramsPerPortion;
  }
}