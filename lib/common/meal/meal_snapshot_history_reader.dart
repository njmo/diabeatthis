import '../../core/drift/database_impl.dart';
import '../../core/logger/logger.dart';

typedef MealSnapshotHistoryRead = ({
  bool available,
  List<MealSnapshotData> snapshots,
});

/// Optional aggregate history must not discard independently available facts.
class MealSnapshotHistoryReader with Logging {
  const MealSnapshotHistoryReader(this.db);
  final DatabaseImpl db;

  Future<MealSnapshotHistoryRead> read(int mealId) async {
    try {
      final snapshots = await (db.select(
        db.mealSnapshot,
      )..where((row) => row.mealId.equals(mealId))).get();
      return (
        available: true,
        snapshots: List<MealSnapshotData>.unmodifiable(snapshots),
      );
    } catch (error, stackTrace) {
      logW(
        'Snapshot history unavailable for meal $mealId: $error\n$stackTrace',
      );
      return (available: false, snapshots: const <MealSnapshotData>[]);
    }
  }
}
