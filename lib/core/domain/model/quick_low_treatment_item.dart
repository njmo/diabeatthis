import 'ingredient.dart';
import 'portion.dart';

const int maxQuickLowTreatmentItems = 6;

class QuickLowTreatmentItem {
  const QuickLowTreatmentItem({
    required this.id,
    required this.name,
    required this.ingredient,
    required this.portion,
    required this.amount,
    required this.sortOrder,
    required this.gramsPerPortion,
  });

  final int id;
  final String name;
  final Ingredient ingredient;
  final Portion? portion;
  final double amount;
  final int sortOrder;
  final double? gramsPerPortion;

  QuickLowTreatmentItem copyWith({int? sortOrder}) {
    return QuickLowTreatmentItem(
      id: id,
      name: name,
      ingredient: ingredient,
      portion: portion,
      amount: amount,
      sortOrder: sortOrder ?? this.sortOrder,
      gramsPerPortion: gramsPerPortion,
    );
  }
}
