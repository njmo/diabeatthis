import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/theme/application_theme_data.dart';
import 'package:diabeatthis/common/widgets/application_backdrop.dart';
import 'package:diabeatthis/common/widgets/detail_identity_header.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_page_state.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page_body.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_preview_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/meals/presentation/widgets/meal_details/meal_cards_test.dart'
    show cardSnapshot;
import '../../features/meals/presentation/widgets/meal_details/meal_low_treatments_display_test.dart'
    show mealDetailsWithLowTreatment, mealRecord;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'warm shared theme keeps planned meal readable in ${brightness.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final details = mealDetailsWithLowTreatment().copyWith(
          meal: mealRecord(
            id: 1,
            name:
                'Kurczak w sosie koperkowym z buraczkami i tłuczonymi ziemniakami',
            plannedAt: DateTime(2026, 11, 4, 14, 57),
            status: 'planned',
          ),
          plannedSnapshot: cardSnapshot('planned', 50, 580),
        );
        final theme = applicationThemeData(
          brightness: brightness,
          textTheme: ThemeData(brightness: brightness).textTheme,
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('pl'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: theme,
              builder: (context, child) => RepaintBoundary(
                key: key,
                child: ApplicationBackdrop(child: child!),
              ),
              home: Scaffold(
                appBar: AppBar(title: const Text('Podgląd posiłku')),
                body: MealPageBody(state: MealPageState(details: details)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DetailIdentityHeader), findsOneWidget);
        expect(find.byType(Tab), findsOneWidget);
        expect(find.byType(MealPreviewActions), findsNothing);
        expect(
          tester.getTopLeft(find.text('Zaplanowany')).dy,
          lessThan(tester.getTopLeft(find.text(details.meal.name)).dy),
        );
        expect(theme.scaffoldBackgroundColor, Colors.transparent);
        expect(theme.tabBarTheme.indicator, isA<UnderlineTabIndicator>());
        expect(find.textContaining('Planowana porcja ·'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
