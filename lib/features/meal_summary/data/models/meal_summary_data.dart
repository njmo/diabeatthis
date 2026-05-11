import 'meal_summary_item.dart';

class MealSummaryData {
  final int mealId;
  final String? mealStatus;
  final List<MealSummaryItem> items;

  MealSummaryData({
    required this.mealId,
    required this.mealStatus,
    required this.items,
  });
}
