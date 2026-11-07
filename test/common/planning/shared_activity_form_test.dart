import 'package:diabeatthis/common/family_sync/presentation/family_activity_plan_form.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'family uses shared activity sheet and requires duration without patient tables',
    (tester) async {
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith(
              (_) => throw StateError('No local writes'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FamilyActivityPlanForm(
                rows: const [
                  {
                    'kind': 'activities',
                    'id': '1',
                    'payload': {
                      'id': 1,
                      'name': 'Swimming',
                      'percentage_pre': 80,
                      'percentage_post': 90,
                      'duration_minutes': null,
                    },
                  },
                ],
                initial: const {'activityId': 1},
                onSubmit: (values) async {
                  sent = values;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DashboardActivitySheet), findsOneWidget);
      final language = AppLocalizations.of(
        tester.element(find.byType(DashboardActivitySheet)),
      );
      expect(find.byType(SegmentedButton<ActivityEntryMode>), findsOneWidget);
      await tester.tap(find.text(language.activitySingleSave));
      await tester.pumpAndSettle();
      expect(sent, isNull);
      expect(find.text(language.activityDurationRequired), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '45');
      await tester.pumpAndSettle();
      await tester.tap(find.text(language.activitySingleSave));
      await tester.pumpAndSettle();
      expect(sent!['activityId'], 1);
      expect(sent!['durationMinutes'], 45);
      expect(tester.takeException(), isNull);
    },
  );
}
