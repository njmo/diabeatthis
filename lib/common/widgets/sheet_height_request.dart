import 'package:flutter/widgets.dart';

/// Lets a form step request a compact fraction of the available sheet height.
class SheetHeightRequest extends Notification {
  const SheetHeightRequest(this.factor);
  final double factor;
}
