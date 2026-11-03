import '../../data/models/meal_details_data.dart';

class MealOriginReview {
  const MealOriginReview({
    required this.sourceId,
    required this.source,
    required this.templateId,
    required this.usages,
  });
  final int? sourceId;
  final MealCopySourceData? source;
  final int? templateId;
  final List<MealCopyUsageData> usages;
}
