import 'dart:convert';

import '../../../../core/drift/database_impl.dart';
import '../../domain/models/accepted_day_summary.dart' as domain;
import '../../domain/models/day_summary_snapshot.dart';

/// Insert-only archive; synchronization and draft rebuilding never write here.
class DaySummaryRepository {
  final DatabaseImpl db;
  const DaySummaryRepository(this.db);

  Future<domain.AcceptedDaySummary?> get(String dayKey) async {
    final row = await (db.select(
      db.acceptedDaySummary,
    )..where((row) => row.dayKey.equals(dayKey))).getSingleOrNull();
    if (row == null) return null;
    final payload = jsonDecode(row.payload) as Map<String, dynamic>;
    final snapshot = DaySummarySnapshot.fromJson(payload);
    return domain.AcceptedDaySummary(
      acceptedAt: DateTime.fromMillisecondsSinceEpoch(row.acceptedAt),
      snapshot: snapshot,
      utcOffsetMinutes:
          payload['acceptedUtcOffsetMinutes'] as int? ??
          snapshot.utcOffsetMinutes,
    );
  }

  Future<void> insert(domain.AcceptedDaySummary summary) => db.transaction(
    () async {
      // A unique day key makes simultaneous acceptance atomic: no replacement.
      await db
          .into(db.acceptedDaySummary)
          .insert(
            AcceptedDaySummaryCompanion.insert(
              dayKey: summary.snapshot.dayKey,
              acceptedAt: summary.acceptedAt.millisecondsSinceEpoch,
              payload: jsonEncode({
                ...summary.snapshot.toJson(),
                'acceptedUtcOffsetMinutes': summary.utcOffsetMinutes,
              }),
            ),
          );
    },
  );
}
