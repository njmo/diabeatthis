import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'sheet_height_request.dart';

/// Keeps a scaffold's footer above the keyboard inside a bounded modal sheet.
class KeyboardAwareSheetFrame extends HookWidget {
  const KeyboardAwareSheetFrame({
    super.key,
    required this.child,
    this.heightFactor = 0.9,
  });
  final Widget child;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final requestedHeight = useState(heightFactor);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    return NotificationListener<SheetHeightRequest>(
      onNotification: (request) {
        requestedHeight.value = request.factor.clamp(0.3, 0.95);
        return true;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: math.max(
                0,
                constraints.maxHeight * requestedHeight.value - keyboardHeight,
              ),
              child: MediaQuery.removeViewInsets(
                context: context,
                removeBottom: true,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
