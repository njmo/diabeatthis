import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'add button is centered above the notch while the page extends underneath',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 800),
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(bottom: 24),
                viewPadding: const EdgeInsets.only(bottom: 24),
              ),
              child: Builder(
                builder: (context) => Scaffold(
                  extendBody: true,
                  bottomNavigationBar: DashboardBottomBar(
                    selectedIndex: 0,
                    onSelected: (_) {},
                  ),
                  floatingActionButtonLocation:
                      FloatingActionButtonLocation.centerDocked,
                  floatingActionButton: FloatingActionButton(
                    onPressed: () {},
                    child: const Icon(Icons.add),
                  ),
                  body: const ColoredBox(
                    key: ValueKey('page'),
                    color: Colors.blue,
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final capsule = tester.getRect(
          find.descendant(
            of: find.byType(BottomAppBar),
            matching: find.byType(Material),
          ),
        );
        final button = tester.getRect(find.byType(FloatingActionButton));
        expect(button.center.dx, closeTo(capsule.center.dx, 0.1));
        expect(button.center.dy, closeTo(capsule.top, 0.1));
        expect(
          tester.getRect(find.byKey(const ValueKey('page'))).bottom,
          greaterThan(capsule.bottom),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
