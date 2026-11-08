import 'dart:async';

import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_nightscout_snapshot.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_refresh_state.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_visible_state_provider.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/caregiver_nightscout_panel.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_target_actions.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_target_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'caregiver target shares live progress and expires without local actions',
    (tester) async {
      final start = DateTime(2026, 11, 8, 12);
      final time = StreamController<DateTime>();
      addTearDown(time.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeNowProvider.overrideWith((_) => time.stream),
            caregiverVisibleStateProvider.overrideWithValue(
              CaregiverRefreshState(
                snapshot: CaregiverNightscoutSnapshot(
                  targetFetched: true,
                  hasFailures: false,
                  temporaryTarget: TemporaryTarget(
                    nightscoutId: 'target',
                    createdAt: start,
                    duration: 30,
                    durationInMiliseconds: 1800000,
                    targetBottom: 100,
                    targetTop: 110,
                  ),
                ),
              ),
            ),
          ],
          child: localizedMaterialApp(
            home: const Scaffold(
              body: SingleChildScrollView(child: CaregiverNightscoutPanel()),
            ),
          ),
        ),
      );
      time.add(start.add(const Duration(minutes: 10)));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardTargetProgress), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(1 / 3, .001),
      );
      expect(find.byType(DashboardTargetActions), findsNothing);
      time.add(start.add(const Duration(minutes: 20)));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(2 / 3, .001),
      );
      time.add(start.add(const Duration(minutes: 30)));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardTargetProgress), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
