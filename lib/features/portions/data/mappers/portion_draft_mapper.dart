import '../../../../core/domain/model/portion.dart' as domain;
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