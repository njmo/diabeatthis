import 'package:flutter/widgets.dart';

enum SheetContentSection { body, footer, header }

/// Reports natural content height, independently of the sheet's viewport.
class SheetContentHeightRequest extends Notification {
  const SheetContentHeightRequest(this.section, this.height);
  final SheetContentSection section;
  final double height;
}
