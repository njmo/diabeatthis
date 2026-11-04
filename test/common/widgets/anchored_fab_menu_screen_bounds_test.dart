import 'package:diabeatthis/common/widgets/anchored_fab_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final location in [
    FloatingActionButtonLocation.endFloat,
    FloatingActionButtonLocation.centerDocked,
  ]) {
    testWidgets('all menu columns remain tappable at $location', (
      tester,
    ) async {
      var open = false;
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              floatingActionButtonLocation: location,
              floatingActionButton: AnchoredFabMenu(
                menuWidth: 360,
                open: open,
                onToggle: () => setState(() => open = !open),
                onDismiss: () => setState(() => open = false),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => calls++,
                          child: const Text('Left action'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () => calls++,
                          child: const Text('Right action'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Left action')).dx,
        greaterThanOrEqualTo(16),
      );
      expect(
        tester.getBottomRight(find.text('Right action')).dx,
        lessThanOrEqualTo(784),
      );
      await tester.tap(find.text('Left action'));
      await tester.tap(find.text('Right action'));
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
