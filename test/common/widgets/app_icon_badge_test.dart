import 'package:diabeatthis/common/widgets/app_icon_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppIconBadge renders icon and squircle decoration', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppIconBadge(
            icon: Icons.flash_on,
            color: Colors.amber,
            size: 44,
            iconSize: 24,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.flash_on), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.amber.withValues(alpha: 0.14));
  });

  testWidgets('AppIconBadge renders child widget when provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppIconBadge(
            color: Colors.blue,
            child: Text('AB'),
          ),
        ),
      ),
    );

    expect(find.text('AB'), findsOneWidget);
  });
}
