import 'package:diabeatthis/common/widgets/swipeable_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cards support swiping and pinned tabs without page controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 3,
          child: Scaffold(
            body: Builder(
              builder: (context) => SwipeableCards(
                controller: DefaultTabController.of(context),
                showPageControls: false,
                labels: const ['Overview', 'Portion', 'Events'],
                children: const [
                  SizedBox(height: 1800, child: Text('Glucose summary')),
                  Text('Nutrition summary'),
                  Text('Event summary'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.text('1 / 3'), findsNothing);
    await tester.drag(find.byType(TabBarView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Portion').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Portion'));
    await tester.pumpAndSettle();
    expect(find.text('Nutrition summary').hitTestable(), findsOneWidget);
    await tester.drag(find.byType(TabBarView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Event summary').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    expect(
      DefaultTabController.of(
        tester.element(find.byType(SwipeableCards)),
      ).index,
      0,
    );
    expect(tester.takeException(), isNull);
  });
}
