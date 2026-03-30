import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/meal_summary_controller.dart';

part 'meal_snapshot_controller_provider.g.dart';

@Riverpod(keepAlive: true)
MealSnapshotController mealSnapshotController(Ref ref) {
  return MealSnapshotController(ref: ref);
}