import 'package:diabeatthis/common/widgets/app_pill_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppPillBadge renders label and value with specified color', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPillBadge(
            icon: Icons.water_drop,
            label: 'IOB',
            value: '1.45 U',
            color: Color(0xFF08799E),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.water_drop), findsOneWidget);
    expect(find.text('IOB'), findsOneWidget);
    expect(find.text('1.45 U'), findsOneWidget);
  });

  testWidgets('AppPillBadge handles tap callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPillBadge(
            label: 'Status',
            value: 'OK',
            color: Colors.green,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('OK'));
    expect(tapped, isTrue);
  });

  testWidgets('AppPillBadge renders value-only mode when label is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPillBadge(
            icon: Icons.check,
            value: 'Synced',
            color: Colors.teal,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
  });
}
