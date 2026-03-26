sealed class CopiedMealType {
  final int id;
  final String name;
  final DateTime date;
  final int? copiedFromMealId;
  final int? copiedFromTemplateId;

  const CopiedMealType({
    required this.id,
    required this.name,
    required this.date,
    this.copiedFromMealId,
    this.copiedFromTemplateId,
  });
}

class CopiedMealFromMeal extends CopiedMealType {
  const CopiedMealFromMeal({
    required super.id,
    required super.name,
    required super.date,
    required super.copiedFromMealId,
    required super.copiedFromTemplateId,
  });
}

class CopiedMealFromTemplate extends CopiedMealType {
  const CopiedMealFromTemplate({
    required super.id,
    required super.name,
    required super.date,
    required super.copiedFromMealId,
  });
}

