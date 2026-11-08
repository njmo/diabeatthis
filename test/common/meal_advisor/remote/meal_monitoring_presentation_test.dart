import 'package:diabeatthis/common/family_sync/presentation/family_planned_meal_card.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/meal_start/meal_start_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('monitoring has one trailing icon and opens the meal directly', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      host(
        FamilyPlannedMealCard(
          payload: {
            'name': 'Lunch',
            'status': 'planned',
            'purpose': 'meal',
            'planned_at': DateTime(2026, 11, 8, 12).millisecondsSinceEpoch,
          },
          history: const [],
          locked: true,
          monitoring: true,
          onOpen: () => opened = true,
        ),
      ),
    );
    expect(find.byIcon(Icons.monitor_heart_outlined), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.textContaining('only the child can cancel'), findsNothing);
    await tester.tap(find.text('Lunch'));
    expect(opened, isTrue);
  });

  testWidgets('a meal header omits the empty subtitle', (tester) async {
    await tester.pumpWidget(
      host(
        const MealStartHeader(title: 'Lunch', subtitle: '', showClose: false),
      ),
    );
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text(''), findsNothing);
  });
}
