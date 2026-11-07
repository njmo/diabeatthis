import 'package:diabeatthis/common/family_sync/presentation/family_activity_log_card.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_planned_activity_card.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_planned_meal_card.dart';
import 'package:diabeatthis/common/family_sync/presentation/models/family_ingredient_view.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/widgets/activity_log_card.dart';
import 'package:diabeatthis/common/presentation/widgets/activity_occurrence_view.dart';
import 'package:diabeatthis/common/presentation/widgets/meal_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test(
    'cloud ingredient preserves nutrition and identity without a database',
    () {
      final item = familyIngredientView({
        'id': '42',
        'payload': {
          'name': 'Apple',
          'brand': 'Farm',
          'carbs_per_100g': 15,
          'fat_per_100g': 1,
          'protein_per_100g': 2,
          'fiber_per_100g': 3,
          'is_reference': 1,
          'carbs_label_mode': 'non_eu',
        },
      });
      expect(item.id, 42);
      expect(item.brand, 'Farm');
      expect(item.isReference, isTrue);
      expect(item.carbsPer100g, 15);
      expect(item.fiberPer100g, 3);
      expect(item.kcalPer100g, 77);
      expect(item.netKcalPer100g, 65);
    },
  );

  testWidgets(
    'caregiver uses shared occurrence and exposes only planning actions',
    (tester) async {
      var confirms = 0;
      var moves = 0;
      final payload = {
        'started_at': DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
        'duration_minutes': 30,
        'status': 'pending',
      };
      await tester.pumpWidget(
        host(
          FamilyPlannedActivityCard(
            payload: payload,
            name: 'Walk',
            locked: false,
            onConfirm: () => confirms++,
            onMove: () => moves++,
          ),
        ),
      );
      expect(find.byType(ActivityOccurrenceView), findsOneWidget);
      expect(find.byType(TextButton), findsNWidgets(2));
      final buttons = tester
          .widgetList<TextButton>(find.byType(TextButton))
          .toList();
      buttons[0].onPressed!();
      buttons[1].onPressed!();
      expect(confirms, 1);
      expect(moves, 1);
      expect(find.byType(IconButton), findsNothing);
      await tester.pumpWidget(
        host(
          FamilyPlannedActivityCard(
            payload: payload,
            name: 'Walk',
            locked: false,
            monitoring: true,
            onConfirm: () => confirms++,
            onMove: () => moves++,
          ),
        ),
      );
      expect(find.byType(TextButton), findsNothing);
    },
  );

  testWidgets(
    'caregiver log uses child history rendering without editable navigation',
    (tester) async {
      await tester.pumpWidget(
        host(
          FamilyActivityLogCard(
            name: 'Walk',
            payload: {
              'started_at': 1700000000000,
              'ended_at': 1700001800000,
              'notes': 'Outside',
            },
          ),
        ),
      );
      expect(find.byType(ActivityLogCard), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('Outside'), findsOneWidget);
      expect(find.textContaining('2023'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    },
  );

  testWidgets(
    'family meal uses shared meal entry with readonly detail content',
    (tester) async {
      await tester.pumpWidget(
        host(
          FamilyPlannedMealCard(
            payload: {
              'name': 'Lunch',
              'status': 'eating',
              'purpose': 'meal',
              'planned_at': 1700000000000,
            },
            history: const [],
            locked: false,
          ),
        ),
      );
      expect(find.byType(MealEntryCard), findsOneWidget);
      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();
      expect(find.byType(TextButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
