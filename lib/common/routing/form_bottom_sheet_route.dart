import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../widgets/keyboard_aware_sheet_frame.dart';

/// Presents a routed form as a sheet while preserving typed navigation results.
Route<T> formBottomSheetRoute<T>(
  BuildContext context,
  Widget child,
  AutoRoutePage<T> page,
) {
  return ModalBottomSheetRoute<T>(
    settings: page,
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
    builder: (_) => KeyboardAwareSheetFrame(child: child),
  );
}
