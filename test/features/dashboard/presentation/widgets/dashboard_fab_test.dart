import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_fab.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('disables quick meal action while another meal is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anyMealBlockingActivationProvider.overrideWith(
            (ref) => Stream.value(
              const Meal(id: 1, name: 'Aktywny', status: 'waiting-for-bolus'),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: DashboardFAB())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Zjedz coś na szybko'), findsOneWidget);

    await tester.tap(find.text('Zjedz coś na szybko'));
    await tester.pumpAndSettle();

    expect(find.text('Wyszukaj składnik'), findsNothing);
  });
}
