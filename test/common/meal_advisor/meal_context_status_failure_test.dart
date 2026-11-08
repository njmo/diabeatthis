import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_context_status.dart';
import 'package:diabeatthis/common/presentation/details/nightscout_record_history.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../history/nightscout_statistics_fixture.dart';

void main() {
  for (final connectionFails in [true, false]) {
    testWidgets(
      'failed context refresh stays red while cached meal content remains visible: connection=$connectionFails',
      (tester) async {
        final now = DateTime(2026, 11, 8, 12);
        var loads = 0;
        Widget fallback(bool failed) => Column(
          children: [
            const Text('Cached meal'),
            MealDecisionContextStatus(
              syncedAt: now,
              glucoseAt: now,
              iobAt: now,
              cobAt: now,
              referenceTime: now,
              syncFailed: failed,
              syncing: !failed,
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nightscoutRepositoryProvider.overrideWith((ref) async {
                if (connectionFails) throw StateError('Connection failed');
                return StatisticsNightscout();
              }),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: NightscoutRecordHistory<bool>(
                    recordKey: 'context',
                    expandFallback: false,
                    fallback: fallback(false),
                    errorFallback: fallback(true),
                    load: (ref, history) async {
                      loads++;
                      throw StateError('History failed');
                    },
                    builder: (_) => const Text('Unexpected success'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Cached meal'), findsOneWidget);
        expect(find.text('Synchronization failed'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsNothing);
        expect(loads, connectionFails ? 0 : 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
