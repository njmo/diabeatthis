import '../../../../core/domain/model/temporary_target.dart';

class MealTargetPreparation {
  const MealTargetPreparation({
    required this.target,
    required this.mealStartedAt,
  });
  final TemporaryTarget target;
  final DateTime mealStartedAt;
  Duration get leadTime => mealStartedAt.difference(target.createdAt);
}
