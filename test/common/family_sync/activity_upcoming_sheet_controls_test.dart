import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family_sync/family_access_scope.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_upcoming_activities.dart';
import 'package:diabeatthis/common/presentation/widgets/activity_upcoming_sessions_button.dart';
import 'package:diabeatthis/common/presentation/widgets/activity_upcoming_sessions_view.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import '../presentation/caregiver_audit_fixture.dart';
import '../presentation/family_collection_fixtures.dart';

void main() {
  for (final count in [0, 1, 20]) {
    testWidgets('sheet height fits $count sessions and scrolls when needed', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: ActivityUpcomingSessionsButton(
              contentBuilder: (_) => ActivityUpcomingSessionsView(
                emptyLabel: 'Empty',
                entries: [
                  for (var i = 0; i < count; i++)
                    SizedBox(height: 120, child: Text('Session $i')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      final height = tester.getSize(find.byType(BottomSheet)).height;
      expect(height, lessThan(600 * 0.9));
      if (count < 2) expect(height, lessThan(300));
      if (count == 20) {
        await tester.scrollUntilVisible(
          find.text('Session 19'),
          200,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Session 19'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'caregiver planned card retains skip and reschedule until preparing',
    (tester) async {
      final f = CaregiverAuditFixture();
      addTearDown(f.close);
      final now = DateTime.now();
      final start = now.add(const Duration(days: 4));
      f.family.rows['activityOccurrences/9'] =
          mirrorRow('activityOccurrences', 9, {
            'activity_id': 5,
            'started_at': start.millisecondsSinceEpoch,
            'status': 'planned',
            'activity_log_id': 7,
            'target_requested_at': now.millisecondsSinceEpoch,
          });
      f.family.rows['activityLogs/7'] = mirrorRow('activityLogs', 7, {
        'activity_id': 5,
        'started_at': start.millisecondsSinceEpoch,
        'ended_at': null,
      });
      f.family.rows['workflowLocks/1'] = mirrorRow('workflowLocks', 1, {
        'kind': 'activity',
        'entity_id': 7,
        'active': 1,
        'phase': 'planned',
      });
      final sent = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAccountProvider.overrideWith(
              (_) => Stream.value(
                const GoogleAccount(
                  uid: 'parent',
                  email: 'p@example.test',
                  displayName: 'Parent',
                ),
              ),
            ),
            timeNowProvider.overrideWith((_) => Stream.value(now)),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: FamilyUpcomingActivities(
                scope: FamilyAccessScope(f.family),
                edit: (type, {targetId, initial}) async {
                  sent.add(type);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pomiń zajęcia'), findsOneWidget);
      expect(find.text('Przełóż'), findsOneWidget);
      await tester.tap(find.text('Pomiń zajęcia'));
      await tester.tap(find.text('Przełóż'));
      expect(sent, ['skipActivity', 'moveActivity']);
      (f.family.rows['workflowLocks/1']!['payload'] as Map)['phase'] =
          'preparing';
      f.family.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Pomiń zajęcia'), findsNothing);
      expect(find.text('Przełóż'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
