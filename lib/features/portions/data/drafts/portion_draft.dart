import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/model/portion.dart';

part 'portion_draft.freezed.dart';

@Freezed(unionKey: 'kind')
abstract class PortionSelection with _$PortionSelection
{
  const factory PortionSelection.draft({
    required String name,
    required String unitHint,
  }) = _PortionSelectionNew;

  const factory PortionSelection.existing({
    required int id,
    required String name,
    required String unitHint,
  }) = _PortionSelectionExisting;
}

