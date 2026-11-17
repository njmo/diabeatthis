import 'dart:async';

import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/day/day_device_age_card.dart';
import 'package:diabeatthis/common/presentation/day/day_glucose_chart.dart';
import 'package:diabeatthis/common/presentation/day/day_night_summary_card.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/caregiver_day_summary.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/day_presentations/caregiver_day_timeline_view.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_activity_card.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_ai_button.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_meals_card.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_review_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../common/history/day_statistics_nightscout.dart';
import '../../helpers/localized_material_app.dart';
import '../../helpers/regression/setup_live_services.dart';

class ControlledDayNightscout extends DayStatisticsNightscout {
  ControlledDayNightscout(super.day, this.responses);
  final List<Completer<List<Glucose>>> responses;
  int requests = 0;
  @override
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end) {
    requests++;
    return responses.removeAt(0).future;
  }
}

void main() {
  final selected = DateTime(2026, 11, 5);
  testWidgets(
    'caregiver shows timeline view without local DB, links or AI; retry recovers one missing source',
    (tester) async {
      final repository = DayStatisticsNightscout(selected)..failGlucose = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAccountProvider.overrideWith(
              (ref) => Stream.value(const GoogleAccount(uid: 'parent')),
            ),
            applicationDeviceModeProvider.overrideWith(
              (ref) async => ApplicationDeviceMode.caregiver,
            ),
            nightscoutRepositoryProvider.overrideWith(
              (ref) async => repository,
            ),
            databaseProvider.overrideWith(
              (ref) => throw StateError('No local patient database'),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CaregiverDaySummary(date: selected),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CaregiverDayTimelineView), findsOneWidget);
      expect(find.byType(DayDeviceAgeCard), findsOneWidget);
      expect(find.byType(DayNightSummaryCard), findsOneWidget);
      expect(find.byType(DayGlucoseChart), findsOneWidget);
      expect(find.byType(DayMealsCard), findsNothing);
      expect(find.byType(DayActivityCard), findsNothing);
      expect(find.byType(DayReviewSection), findsNothing);
      expect(find.byType(DayAiButton), findsNothing);
      expect(find.text('--'), findsWidgets);

      repository.failGlucose = false;
      final context = tester.element(find.byType(CaregiverDaySummary));
      await tester.tap(find.byTooltip(context.lang.dayRefresh));
      await tester.pumpAndSettle();
      expect(find.text('120'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final change in ['date', 'connection', 'account', 'family']) {
    testWidgets('pending old statistics cannot replace new $change data', (
      tester,
    ) async {
      final old = Completer<List<Glucose>>();
      final latest = Completer<List<Glucose>>();
      final original = ControlledDayNightscout(selected, [old, latest]);
      var repository = original;
      var date = selected;
      var source = 'first-family-source';
      late StateSetter update;
      final auth = SetupGoogleAuthenticationTestRepository();
      final container = ProviderContainer(
        overrides: [
          googleAuthenticationRepositoryProvider.overrideWithValue(auth),
          applicationDeviceModeProvider.overrideWith(
            (ref) async => ApplicationDeviceMode.caregiver,
          ),
          nightscoutRepositoryProvider.overrideWith((ref) async => repository),
          databaseProvider.overrideWith(
            (ref) => throw StateError('No patient DB'),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return CaregiverDaySummary(
                      date: date,
                      owner: 'child',
                      source: source,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      auth.accounts.add(const GoogleAccount(uid: 'parent'));
      await tester.pump();
      await tester.pump();
      expect(original.requests, 1);
      if (change == 'date') update(() => date = DateTime(2026, 11, 4));
      if (change == 'family') update(() => source = 'next-family-source');
      if (change == 'connection') {
        repository = ControlledDayNightscout(selected, [latest]);
        container.invalidate(nightscoutRepositoryProvider);
      }
      if (change == 'account') {
        auth.accounts.add(const GoogleAccount(uid: 'another-parent'));
      }
      await tester.pump();
      await tester.pump();
      latest.complete([
        Glucose(
          externalId: 'new',
          source: GlucoseSource.cloud,
          date: date.add(const Duration(hours: 12)),
          sgv: 155,
          direction: 'Flat',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('155'), findsWidgets);
      old.complete([
        Glucose(
          externalId: 'old',
          source: GlucoseSource.cloud,
          date: selected.add(const Duration(hours: 12)),
          sgv: 111,
          direction: 'Flat',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('155'), findsWidgets);
      expect(find.text('111'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.runAsync(auth.dispose);
    });
  }
}
