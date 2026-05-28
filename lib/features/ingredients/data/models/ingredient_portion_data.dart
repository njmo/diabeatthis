class IngredientPortionData {
  int portionId;
  String name;
  String unitHint;
  double gramsPerPortion;

  IngredientPortionData({
    required this.portionId,
    required this.name,
    required this.unitHint,
    required this.gramsPerPortion,
  });

  IngredientPortionData copyWith({
    int? portionId,
    String? name,
    String? unitHint,
    double? gramsPerPortion,
  }) {
    return IngredientPortionData(
      portionId: portionId ?? this.portionId,
      name: name ?? this.name,
      unitHint: unitHint ?? this.unitHint,
      gramsPerPortion: gramsPerPortion ?? this.gramsPerPortion,
    );
  }
}
