import 'package:freezed_annotation/freezed_annotation.dart';

part 'portion_draft.freezed.dart';

@Freezed(unionKey: 'kind')
abstract class PortionSelection with _$PortionSelection {
  const factory PortionSelection.draft({
    required String name,
    required String unitHint,
  }) = _PortionSelectionDraft;

  const factory PortionSelection.existing({
    required int id,
    required String name,
    required String unitHint,
  }) = _PortionSelectionExisting;

  const factory PortionSelection.empty() = _PortionSelectionEmpty;
}
