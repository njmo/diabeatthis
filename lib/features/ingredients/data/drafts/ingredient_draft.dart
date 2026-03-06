import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../portions/data/drafts/portion_draft.dart';

part 'ingredient_draft.freezed.dart';

@freezed
abstract class IngredientPortion with _$IngredientPortion
{
  const factory IngredientPortion( {
    required PortionSelection portion,
    required int amount,
  }) = _IngredientPortion;
}