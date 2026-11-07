import 'dart:async';

import 'package:diabeatthis/common/family_sync/presentation/family_activity_log_card.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('caregiver activity follows local clock without cloud refresh', (
    tester,
  ) async {
    final clock = StreamController<DateTime>();
    final start = DateTime(2026, 11, 7, 12);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [timeNowProvider.overrideWith((ref) => clock.stream)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FamilyActivityLogCard(
              payload: {
                'id': 1,
                'activity_id': 2,
                'started_at': start.millisecondsSinceEpoch,
              },
              name: 'Walk',
              durationMinutes: 30,
            ),
          ),
        ),
      ),
    );
    clock.add(start.add(const Duration(minutes: 1)));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<DashboardActivityCard>(find.byType(DashboardActivityCard))
          .now,
      start.add(const Duration(minutes: 1)),
    );
    clock.add(start.add(const Duration(minutes: 2)));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<DashboardActivityCard>(find.byType(DashboardActivityCard))
          .now,
      start.add(const Duration(minutes: 2)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(clock.close);
  });
}
