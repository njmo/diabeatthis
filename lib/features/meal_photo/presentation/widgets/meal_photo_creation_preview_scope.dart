import 'package:flutter/widgets.dart';

import '../../domain/models/meal_photo_review_item.dart';

class MealPhotoCreationPreviewScope extends InheritedWidget {
  const MealPhotoCreationPreviewScope({
    super.key,
    required this.check,
    required super.child,
  });
  final Future<bool?> Function(MealPhotoReviewItem)? check;

  static MealPhotoCreationPreviewScope? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MealPhotoCreationPreviewScope>();

  @override
  bool updateShouldNotify(MealPhotoCreationPreviewScope oldWidget) =>
      check != oldWidget.check;
}
