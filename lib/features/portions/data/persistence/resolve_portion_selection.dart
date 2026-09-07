import 'package:drift/drift.dart';

import '../../../../core/domain/model/portion.dart' as domain;
import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/mappers/portion_drift_mapper.dart';
import '../drafts/portion_draft.dart';
import '../mappers/portion_draft_mapper.dart';

Future<domain.Portion?> resolvePortionSelection(
  DatabaseImpl db,
  PortionSelection portion,
) async {
  return portion.map(
    draft: (draft) async {
      await db
          .into(db.portion)
          .insert(
            portion.toCompanion(),
            onConflict: DoNothing(
              target: [db.portion.name, db.portion.unitHint],
            ),
          );
      final row =
          await (db.select(db.portion)..where(
                (row) =>
                    row.name.equals(draft.name) &
                    row.unitHint.equals(draft.unitHint),
              ))
              .getSingle();
      return row.toDomain();
    },
    existing: (existing) => existing.toDomain(),
    empty: (_) => null,
  );
}
