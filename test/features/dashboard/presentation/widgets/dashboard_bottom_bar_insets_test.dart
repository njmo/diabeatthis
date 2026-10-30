import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('system navigation inset remains outside the painted capsule', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final inset in [0.0, 24.0, 34.0]) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 800),
              padding: EdgeInsets.only(bottom: inset),
              viewPadding: EdgeInsets.only(bottom: inset),
            ),
            child: Scaffold(
              bottomNavigationBar: DashboardBottomBar(
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      final surface = find.descendant(
        of: find.byType(BottomAppBar),
        matching: find.byType(Material),
      );
      final bounds = tester.getRect(surface);
      expect(bounds.height, 64);
      expect(bounds.bottom, closeTo(800 - inset - 12, 0.1));
      expect(tester.takeException(), isNull);
    }
  });
}
