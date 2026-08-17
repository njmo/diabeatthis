import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';

final mealStatusStartedAtProvider =
    FutureProvider.family<DateTime?, MealStatusStartedAtRequest>((
      ref,
      request,
    ) async {
      final db = ref.watch(databaseProvider);
      final history =
          await (db.select(db.mealStatusHistory)
                ..where((tbl) => tbl.mealId.equals(request.mealId))
                ..where((tbl) => tbl.status.equals(request.status))
                ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
                ..limit(1))
              .getSingleOrNull();

      if (history == null) {
        return null;
      }

      return DateTime.fromMillisecondsSinceEpoch(history.createdAt);
    });

class MealStatusStartedAtRequest {
  final int mealId;
  final String status;

  const MealStatusStartedAtRequest({
    required this.mealId,
    required this.status,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MealStatusStartedAtRequest &&
            runtimeType == other.runtimeType &&
            mealId == other.mealId &&
            status == other.status;
  }

  @override
  int get hashCode => Object.hash(mealId, status);
}
