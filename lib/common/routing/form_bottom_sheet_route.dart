import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../widgets/keyboard_aware_sheet_frame.dart';
import '../widgets/responsive_bottom_sheet.dart';

/// Presents a routed form as a sheet while preserving typed navigation results.
Route<T> formBottomSheetRoute<T>(
  BuildContext context,
  Widget child,
  AutoRoutePage<T> page,
) {
  return createFormBottomSheetRoute<T>(context, child, settings: page);
}

Future<T?> showFormBottomSheet<T>(
  BuildContext context,
  Widget child, {
  double? initialContentHeight,
}) => Navigator.of(context).push<T>(
  createFormBottomSheetRoute<T>(
    context,
    child,
    initialContentHeight: initialContentHeight,
  ),
);

Route<T> createFormBottomSheetRoute<T>(
  BuildContext context,
  Widget child, {
  RouteSettings? settings,
  double? initialContentHeight,
}) {
  return ModalBottomSheetRoute<T>(
    settings: settings,
    isScrollControlled: true,
    useSafeArea: true,
    // The form owns back navigation and saving; gestures must not bypass them.
    isDismissible: false,
    enableDrag: false,
    modalBarrierColor: Colors.black54,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => KeyboardAwareSheetFrame(
      initialContentHeight: initialContentHeight,
      child: ResponsiveSheet(child: child),
    ),
  );
}
