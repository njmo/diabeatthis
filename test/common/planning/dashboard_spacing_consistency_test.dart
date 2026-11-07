import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family_sync/family_planning_view.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_planning_page.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/dashboard/dashboard_card_padding.dart';
import 'package:diabeatthis/common/presentation/dashboard/dashboard_spacing.dart';
import 'package:diabeatthis/common/presentation/dashboard/nightscout_panel_view.dart';
import 'package:diabeatthis/common/widgets/status_info_card.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_summary_data.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('both home modes have identical panel and activity spacing', (
    tester,
  ) async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    const panel = NightscoutPanelView(
      lastUpdate: '4 min',
      readings: SizedBox(width: double.infinity, height: 180),
    );
    final now = DateTime.now();
    final start = now.subtract(const Duration(minutes: 1));
    Widget app(Widget home) => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        googleAccountProvider.overrideWith((_) => Stream.value(null)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => SingleChildScrollView(
            padding: DashboardSpacing.homeScroll(context),
            child: Column(
              children: [
                panel,
                DashboardCardPadding(
                  child: DashboardActivityCard(
                    allowLocalActions: false,
                    now: now,
                    activity: ActivityLogSummaryData(
                      id: 1,
                      activityName: 'Walk',
                      activityId: 1,
                      startedAt: start,
                      endedAt: null,
                      durationMinutes: null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final childPanel = tester.getRect(find.byType(Card).first);
    final childActivity = tester.getRect(find.byType(StatusInfoCard));
    await tester.pumpWidget(
      app(
        const FamilyPlanningPage(
          embedded: true,
          view: FamilyPlanningView.home,
          header: panel,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state<FamilyPlanningPageState>(
      find.byType(FamilyPlanningPage),
    );
    state.controller.source = 'cached-source';
    state.controller.rows.addAll({
      'activities/1': {
        'kind': 'activities',
        'id': '1',
        'payload': {'id': 1, 'name': 'Walk', 'duration_minutes': null},
      },
      'activityLogs/1': {
        'kind': 'activityLogs',
        'id': '1',
        'payload': {
          'id': 1,
          'activity_id': 1,
          'started_at': start.millisecondsSinceEpoch,
          'ended_at': null,
        },
      },
    });
    state.changed();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(Card).first), childPanel);
    expect(tester.getRect(find.byType(StatusInfoCard)), childActivity);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
