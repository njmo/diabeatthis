import 'package:diabeatthis/common/widgets/app_icon_badge.dart';
import 'package:diabeatthis/common/widgets/fab_action_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FabActionOption compactCircle renders 42dp circle and label', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FabActionOption(
            compactCircle: true,
            icon: Icons.local_drink_outlined,
            label: 'Dosłodzenie',
            accent: Colors.orange,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.local_drink_outlined), findsOneWidget);
    expect(find.text('Dosłodzenie'), findsOneWidget);

    await tester.tap(find.text('Dosłodzenie'));
    expect(tapped, isTrue);
  });

  testWidgets('FabActionOption horizontal tile renders AppIconBadge and arrow', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FabActionOption(
            tile: true,
            horizontal: true,
            icon: Icons.restaurant,
            label: 'Zaplanuj posiłek',
            accent: Colors.teal,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(AppIconBadge), findsOneWidget);
    expect(find.text('Zaplanuj posiłek'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);

    await tester.tap(find.text('Zaplanuj posiłek'));
    expect(tapped, isTrue);
  });
}
