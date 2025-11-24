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
    return maybeMap(
      draft: (e) => PortionCompanion(
        name: d.Value(e.name),
        unitHint: d.Value(e.unitHint),
      ),
      existing: (e) => PortionCompanion(
        id: d.Value(e.id),
        name: d.Value(e.name),
        unitHint: d.Value(e.unitHint),
      ),
      orElse: () => throw Exception('Cannot convert to companion'),
    );
  }

  domain.Portion toDomain()
  {
    return maybeMap(
      existing: (e) => domain.Portion(id: e.id, name: e.name, unitHint: e.unitHint),
      orElse: () => throw Exception('Cannot convert to domain'),
    );
  }
}
