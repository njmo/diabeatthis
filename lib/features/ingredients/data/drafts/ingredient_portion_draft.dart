import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../portions/data/drafts/portion_draft.dart';

part 'ingredient_portion_draft.freezed.dart';

@freezed
abstract class IngredientPortionDraft with _$IngredientPortionDraft
{
  const factory IngredientPortionDraft( {
    required PortionSelection portion,
    required double amount,
  }) = _IngredientPortionDraft;
}