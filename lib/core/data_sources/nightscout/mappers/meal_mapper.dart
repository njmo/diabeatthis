import '../../../domain/model/meal.dart';
import '../dto/meal_dto.dart';

extension MealMapper on MealDto {
  Meal toDomain({int? localId}) {
    return Meal(
      id: 0,
      createdAt: DateTime.parse(createdAt).toLocal(),
      nightscoutObjectId: id,
      glucose: (glucose as num?)?.toInt() ?? 0,
      insulin:
          (bolusCalculatorResult?['totalInsulin'] as num?)?.toDouble() ?? 0,
      carbs: (bolusCalculatorResult?['carbs'] as num?)?.toInt() ?? 0,
      name: '',
    );
  }
}
