import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'sheet_content_height_request.dart';
import 'sheet_height_request.dart';
import 'sheet_surface.dart';

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
    final naturalHeights = useState(<SheetContentSection, double>{});
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    return NotificationListener<SheetContentHeightRequest>(
      onNotification: (request) {
        if (naturalHeights.value[request.section] != request.height) {
          naturalHeights.value = {
            ...naturalHeights.value,
            request.section: request.height,
          };
        }
        return true;
      },
      child: NotificationListener<SheetHeightRequest>(
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
                  math.min(
                    constraints.maxHeight * requestedHeight.value -
                        keyboardHeight,
                    naturalHeights.value.containsKey(SheetContentSection.body)
                        ? kToolbarHeight +
                              naturalHeights.value.values.fold(
                                0.0,
                                (sum, value) => sum + value,
                              ) +
                              ((naturalHeights.value[SheetContentSection
                                              .footer] ??
                                          0) ==
                                      0
                                  ? MediaQuery.paddingOf(context).bottom
                                  : 0)
                        : double.infinity,
                  ),
                ),
                child: MediaQuery.removeViewInsets(
                  context: context,
                  removeBottom: true,
                  child: SheetSurface(child: child),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
