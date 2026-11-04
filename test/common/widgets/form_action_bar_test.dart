import 'package:diabeatthis/common/widgets/form_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final systemBottom in [0.0, 24.0, 48.0]) {
    testWidgets(
      'action bar adds a 24 px margin above system inset $systemBottom',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                padding: EdgeInsets.only(bottom: systemBottom),
              ),
              child: const Scaffold(
                bottomNavigationBar: FormActionBar(
                  child: SizedBox(key: ValueKey('actions'), height: 48),
                ),
              ),
            ),
          ),
        );
        final bar = tester.getRect(find.byType(FormActionBar));
        final actions = tester.getRect(find.byKey(const ValueKey('actions')));
        expect(bar.bottom - actions.bottom, 24 + systemBottom);
        expect(actions.top - bar.top, 16);
        expect(
          find.descendant(
            of: find.byType(FormActionBar),
            matching: find.byType(Material),
          ),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
