import 'package:diabeatthis/common/widgets/anchored_fab_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'FAB stays docked throughout opening and closing; overlay actions work',
    (tester) async {
      var open = false;
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              bottomNavigationBar: const BottomAppBar(
                shape: CircularNotchedRectangle(),
                child: SizedBox(height: 64),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerDocked,
              floatingActionButton: AnchoredFabMenu(
                open: open,
                onToggle: () => setState(() => open = !open),
                onDismiss: () => setState(() => open = false),
                actions: [
                  SizedBox(
                    width: 230,
                    height: 250,
                    child: TextButton(
                      onPressed: () {
                        actions++;
                        setState(() => open = false);
                      },
                      child: const Text('Action'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getCenter(find.byType(FloatingActionButton));
      expect(before.dy, tester.getTopLeft(find.byType(BottomAppBar)).dy);
      await tester.tap(find.byType(FloatingActionButton));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          (tester.getCenter(find.byType(FloatingActionButton)) - before)
              .distance,
          lessThan(0.01),
        );
      }
      expect(find.text('Action'), findsOneWidget);
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      expect(actions, 1);
      expect(find.text('Action'), findsNothing);
      expect(tester.getCenter(find.byType(FloatingActionButton)), before);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 100));
      await tester.pumpAndSettle();
      expect(find.text('Action'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
