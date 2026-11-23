import 'package:diabeatthis/common/widgets/responsive_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'sheet headings fit the viewport and retain system text scaling',
    (tester) async {
      final theme = ThemeData(
        textTheme: const TextTheme(titleLarge: TextStyle(fontSize: 22)),
      );
      double? heading;
      double? nestedHeading;
      double? accessibleHeading;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showResponsiveBottomSheet<void>(
                context: context,
                builder: (context) {
                  heading = Theme.of(context).textTheme.titleLarge!.fontSize;
                  return ResponsiveSheet(
                    child: Builder(
                      builder: (context) {
                        nestedHeading = Theme.of(
                          context,
                        ).textTheme.titleLarge!.fontSize;
                        accessibleHeading = MediaQuery.textScalerOf(
                          context,
                        ).scale(nestedHeading!);
                        return const Text('Sheet content');
                      },
                    ),
                  );
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 720);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final compactHeading = heading!;
      expect(compactHeading, lessThan(theme.textTheme.titleLarge!.fontSize!));
      expect(nestedHeading, compactHeading);
      expect(accessibleHeading, closeTo(compactHeading * 1.5, .01));

      tester.view.physicalSize = const Size(640, 900);
      await tester.pumpAndSettle();
      expect(heading, greaterThan(compactHeading));
      expect(nestedHeading, heading);
      expect(tester.takeException(), isNull);
    },
  );
}
