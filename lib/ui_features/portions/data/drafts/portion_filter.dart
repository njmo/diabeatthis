import 'package:freezed_annotation/freezed_annotation.dart';

part 'portion_filter.freezed.dart';

@Freezed(unionKey: 'kind')
class PortionFilter with _$PortionFilter {
  const factory PortionFilter.all() = _PortionFilterAll;
  const factory PortionFilter.byQuery() = _PortionFilterByQuery;
  const factory PortionFilter.byQueryForIngredient({required int ingredientId}) = _PortionFilterByQueryForIngredient;
  const factory PortionFilter.allUnassignedForIngredient({required int ingredientId}) = _PortionFilterAllUnassignedForIngredient;
}
