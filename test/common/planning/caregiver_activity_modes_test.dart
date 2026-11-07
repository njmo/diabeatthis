import 'package:diabeatthis/common/family_sync/presentation/family_activity_plan_form.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in ['startActivity', 'logActivity']) {
    testWidgets(
      '$mode uses shared controls and submits only a family proposal',
      (tester) async {
        String? operation;
        Map<String, dynamic>? sent;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWith(
                (_) => throw StateError('No patient database'),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: FamilyActivityPlanForm(
                  operation: mode,
                  rows: const [
                    {
                      'kind': 'activities',
                      'id': '1',
                      'payload': {
                        'id': 1,
                        'name': 'Walk',
                        'percentage_pre': 10,
                        'percentage_post': 10,
                        'duration_minutes': 30,
                      },
                    },
                  ],
                  initial: {
                    'activityId': 1,
                    'startedAt': DateTime.now()
                        .subtract(const Duration(hours: 1))
                        .millisecondsSinceEpoch,
                    'durationMinutes': 30,
                  },
                  onSubmit: (_) async =>
                      throw StateError('Operation type must be retained'),
                  onActivitySubmit: (type, values) async {
                    operation = type;
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
        await tester.tap(
          find.text(
            mode == 'startActivity'
                ? language.activityStartNow
                : language.activityHistorySave,
          ),
        );
        await tester.pumpAndSettle();
        expect(operation, mode);
        expect(sent!['activityId'], 1);
        expect(sent!.containsKey('endedAt'), mode == 'logActivity');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
