import 'package:diabeatthis/common/family_sync/presentation/family_activity_plan_form.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_definition_sheet.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'pencil edits pending definition without returning to empty search or losing the planned duration',
    (tester) async {
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith(
              (_) => throw StateError('No patient DB'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FamilyActivityPlanForm(
                rows: const [],
                initial: {
                  'activityId': null,
                  'activity': {
                    'name': 'Walk',
                    'percentagePre': 20,
                    'percentagePost': 30,
                    'durationMinutes': 30,
                  },
                  'durationMinutes': 45,
                  'startedAt': DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch,
                },
                onSubmit: (values) async {
                  sent = values;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final language = AppLocalizations.of(
        tester.element(find.byType(FamilyActivityPlanForm)),
      );
      await tester.tap(find.byTooltip(language.dashboardChangeActivityTooltip));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityDefinitionSheet), findsOneWidget);
      expect(find.byType(ActivityPickerSheet), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('activity-name-field')),
            )
            .initialValue,
        'Walk',
      );
      await tester.enterText(
        find.byKey(const ValueKey('activity-name-field')),
        'Long walk',
      );
      await tester.tap(find.text(language.commonCreate));
      await tester.pumpAndSettle();
      expect(find.text('Long walk'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller
            ?.text,
        '45',
      );
      await tester.tap(find.text(language.activitySingleSave));
      await tester.pumpAndSettle();
      expect((sent!['activity'] as Map)['name'], 'Long walk');
      expect((sent!['activity'] as Map)['percentagePre'], 20);
      expect(sent!['durationMinutes'], 45);
      expect(tester.takeException(), isNull);
    },
  );
}
