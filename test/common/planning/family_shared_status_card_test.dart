import 'package:diabeatthis/common/family_sync/presentation/family_activity_log_card.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_plan_status_card.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/status_info_card.dart';
import 'package:diabeatthis/features/activity/common/controllers/activity_actions_controller.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_card.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'pending start uses child card without pretending monitoring started or exposing technical data',
    (tester) async {
      final plan = <String, dynamic>{
        'id': 'request',
        'type': 'startActivity',
        'status': 'pending',
        'targetId': null,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'base': [],
        'values': {
          'activityId': null,
          'activity': {'name': 'Walking', 'durationMinutes': 30},
          'startedAt': DateTime.now().millisecondsSinceEpoch,
        },
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityActionsControllerProvider.overrideWith(
              () => throw StateError('No child actions'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FamilyPlanStatusCard(plan: plan, onRetry: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DashboardActivityCard), findsOneWidget);
      expect(find.byType(StatusInfoCard), findsOneWidget);
      expect(find.byType(DashboardActivityProgress), findsNothing);
      expect(find.text('Walking'), findsOneWidget);
      final language = AppLocalizations.of(
        tester.element(find.byType(FamilyPlanStatusCard)),
      );
      expect(find.text(language.familyWaitingForStart), findsOneWidget);
      expect(find.text(language.familyPlanBefore), findsNothing);
      expect(find.text(language.familyPlanProposal), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test('canonical result replaces pending card without duplicate', () {
    final plan = <String, dynamic>{
      'type': 'startActivity',
      'status': 'pending',
      'targetId': null,
      'resultId': 7,
    };
    expect(showFamilyPlanStatus(plan, []), isTrue);
    expect(
      showFamilyPlanStatus(plan, [
        {'kind': 'activityLogs', 'id': '7', 'deleted': false},
      ]),
      isFalse,
    );
  });
  testWidgets(
    'mirrored running log uses the actual child dashboard card with no local actions',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activityActionsControllerProvider.overrideWith(
              () => throw StateError('No child actions'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FamilyActivityLogCard(
                name: 'Walking',
                durationMinutes: 30,
                payload: {
                  'id': 7,
                  'activity_id': 1,
                  'started_at': DateTime.now()
                      .subtract(const Duration(minutes: 2))
                      .millisecondsSinceEpoch,
                  'ended_at': null,
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DashboardActivityCard), findsOneWidget);
      expect(find.byType(DashboardActivityProgress), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
