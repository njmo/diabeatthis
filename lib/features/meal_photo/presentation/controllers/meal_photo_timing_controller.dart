import 'package:flutter/foundation.dart';

import '../../domain/models/meal_photo_timing_selection.dart';

class MealPhotoTimingController extends ChangeNotifier {
  MealPhotoTimingSelection selection = const MealPhotoTimingSelection();
  void chooseMode(MealPhotoTimingMode mode) {
    selection = MealPhotoTimingSelection(
      mode: mode,
      plannedAt: selection.plannedAt,
    );
    notifyListeners();
  }

  void chooseDate(DateTime value) {
    if (selection.mode != MealPhotoTimingMode.planned) return;
    selection = MealPhotoTimingSelection(
      mode: selection.mode,
      plannedAt: value,
    );
    notifyListeners();
  }
}
