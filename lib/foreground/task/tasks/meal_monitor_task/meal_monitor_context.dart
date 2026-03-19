import '../../../../core/domain/model/meal.dart';

class MealMonitorContext {
  Meal? activeMeal;

  MealMonitorContext({this.activeMeal});

  MealMonitorContext copyWith({bool? shouldBolus, Meal? activeMeal}) {
    return MealMonitorContext(
      activeMeal: activeMeal ?? this.activeMeal,
    );
  }
}
