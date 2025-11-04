import 'package:drift/drift.dart' as d;

import '../../../../core/domain/model/portion.dart' as domain;
import '../../../../core/drift/database_impl.dart';
import '../drafts/portion_draft.dart';

extension PortionSelectionMapper on domain.Portion {
  PortionSelection toSelection() {
    return PortionSelection.existing(
      id: id,
      name: name,
      unitHint: unitHint,
    );
  }
}

extension MealDraftToCompanion on PortionSelection {
  PortionCompanion toCompanion() {
    final idValue = maybeWhen<d.Value<int>>(
      existing: (id, name, unitHint) => d.Value(id),
      orElse: () => const d.Value.absent(),
    );

    return PortionCompanion(
      id: idValue,
      name: d.Value(name),
      unitHint: d.Value(unitHint),
    );
  }

  domain.Portion toDomain()
  {
    final idValue = maybeMap<int>(
      existing: (e) => e.id,
      orElse: () => 0,
    );

    return domain.Portion(
      id : idValue,
      name: name,
      unitHint: unitHint,
    );
  }
}
