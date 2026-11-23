import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<T?> showResponsiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  Color? backgroundColor,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  ThemeData? contentTheme,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  useRootNavigator: useRootNavigator,
  useSafeArea: useSafeArea,
  isDismissible: isDismissible,
  enableDrag: enableDrag,
  showDragHandle: showDragHandle,
  backgroundColor: backgroundColor,
  shape: shape,
  clipBehavior: clipBehavior,
  constraints: constraints,
  builder: (_) => ResponsiveSheet(
    baseTheme: contentTheme,
    child: Builder(builder: builder),
  ),
);

/// Keeps design sizing local to sheets. MediaQuery still applies the user's
/// text scaling to these styles, and button hit targets keep their normal size.
class ResponsiveSheet extends StatelessWidget {
  const ResponsiveSheet({super.key, required this.child, this.baseTheme});

  final Widget child;
  final ThemeData? baseTheme;

  static double spacingFactor(BuildContext context) =>
      (MediaQuery.sizeOf(context).shortestSide / 440).clamp(.82, 1.0);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final base =
        baseTheme ??
        context.dependOnInheritedWidgetOfExactType<_SheetBaseTheme>()?.data ??
        Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(media.width, constraints.maxWidth);
        final shortSide = math.min(width, media.height);
        final headingScale = (shortSide / 450).clamp(.80, .94);
        final bodyScale = (shortSide / 410).clamp(.92, 1.0);
        final text = base.textTheme;
        TextStyle? heading(TextStyle? style) =>
            style?.apply(fontSizeFactor: headingScale);
        TextStyle? body(TextStyle? style) =>
            style?.apply(fontSizeFactor: bodyScale);
        ButtonStyle button(ButtonStyle? style) =>
            (style ?? const ButtonStyle()).copyWith(
              minimumSize: WidgetStateProperty.resolveWith(
                (states) =>
                    Size(style?.minimumSize?.resolve(states)?.width ?? 0, 44),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              ),
              textStyle: WidgetStateProperty.resolveWith(
                (states) =>
                    body(style?.textStyle?.resolve(states) ?? text.labelLarge),
              ),
            );
        return _SheetBaseTheme(
          data: base,
          child: Theme(
            data: base.copyWith(
              textTheme: text.copyWith(
                headlineLarge: heading(text.headlineLarge),
                headlineMedium: heading(text.headlineMedium),
                headlineSmall: heading(text.headlineSmall),
                titleLarge: heading(text.titleLarge),
                titleMedium: heading(text.titleMedium),
                bodyLarge: body(text.bodyLarge),
                bodyMedium: body(text.bodyMedium),
                labelLarge: body(text.labelLarge),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: button(base.filledButtonTheme.style),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: button(base.elevatedButtonTheme.style),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: button(base.outlinedButtonTheme.style),
              ),
              inputDecorationTheme: base.inputDecorationTheme.copyWith(
                isDense: true,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _SheetBaseTheme extends InheritedTheme {
  const _SheetBaseTheme({required this.data, required super.child});

  final ThemeData data;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      _SheetBaseTheme(data: data, child: child);

  @override
  bool updateShouldNotify(_SheetBaseTheme oldWidget) => data != oldWidget.data;
}
