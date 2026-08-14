import '../../../../core/domain/model/carbs_label_mode.dart';
import 'ingredient_history_entry_data.dart';
import 'ingredient_portion_data.dart';
import 'ingredient_usage_data.dart';

class Ingredient {
  int id;
  String name;
  double carbsPer100g;
  double fatPer100g;
  double fiberPer100g;
  double proteinPer100g;
  double nutritionConfidence;
  bool isReference;
  CarbsLabelMode carbsLabelMode;
  double? netKcalPer100g;
  double? kcalPer100g;
  double? wbtKcalPer100g;
  int? ig;
  String? preparation;
  String? brand;
  String? barcode;

  Ingredient({
    required this.id,
    required this.name,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    required this.proteinPer100g,
    required this.nutritionConfidence,
    required this.isReference,
    required this.carbsLabelMode,
    this.netKcalPer100g,
    this.kcalPer100g,
    this.wbtKcalPer100g,
    this.ig,
    this.preparation,
    this.brand,
    this.barcode,
  });
}

class IngredientDetailsData {
  Ingredient ingredient;
  List<IngredientPortionData> portions;
  List<IngredientUsageData> usages;
  List<IngredientHistoryEntryData> history;

  IngredientDetailsData({
    required this.ingredient,
    required this.portions,
    required this.usages,
    required this.history,
  });

  IngredientDetailsData copyWith({
    Ingredient? ingredient,
    List<IngredientPortionData>? portions,
    List<IngredientUsageData>? usages,
    List<IngredientHistoryEntryData>? history,
  }) {
    return IngredientDetailsData(
      ingredient: ingredient ?? this.ingredient,
      portions: portions ?? this.portions,
      usages: usages ?? this.usages,
      history: history ?? this.history,
    );
  }
}
