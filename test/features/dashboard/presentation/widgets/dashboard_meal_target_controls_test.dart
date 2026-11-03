import 'package:clock/clock.dart';
import 'package:diabeatthis/features/dashboard/common/widgets/status_time_progress.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show MealData;
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/linked_target_meal_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/temporary_target_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  final now = DateTime(2026, 11, 3, 8);
  for (final enabled in [false, true]) {
    for (final linked in [false, true]) {
      testWidgets('meal target control=$enabled linked=$linked fits a small screen', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({
          nightscoutUrlKey: 'https://example.com',
          nightscoutTokenKey: 'test-token',
          nightscoutTempTargetsEnabledKey: enabled,
        });
        final prefs = await SharedPreferences.getInstance();
        final target = TemporaryTarget(
          nightscoutId: 'meal-target', createdAt: now.subtract(const Duration(minutes: 15)),
          durationInMiliseconds: 3600000, duration: 60, targetBottom: 90, targetTop: 90,
        );
        final meal = MealData(id: 1, name: 'Śniadanie', plannedAt: now.millisecondsSinceEpoch,
          purpose: 'meal', status: 'planned', createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch, isSynced: false);
        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(ProviderScope(
            overrides: [
              sharedPrefsProvider.overrideWith((_) async => prefs),
              getPendingActivityProvider.overrideWithValue(const AsyncData(null)),
              linkedTargetMealProvider(target).overrideWithValue(AsyncData(linked ? meal : null)),
              timeNowProvider.overrideWithValue(AsyncData(now)),
            ],
            child: localizedMaterialApp(home: const Scaffold(body: DashboardStatusCard())),
          ));
          final container = ProviderScope.containerOf(tester.element(find.byType(DashboardStatusCard)));
          container.read(temporaryTargetUiProvider.notifier).update(target);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byTooltip('Zatrzymaj cel tymczasowy'), enabled ? findsOneWidget : findsNothing);
          expect(find.byTooltip('Podepnij posiłek'), linked ? findsNothing : findsOneWidget);
          expect(find.text('Śniadanie'), linked ? findsOneWidget : findsNothing);
          expect(find.byType(StatusTimeProgress), findsOneWidget);
        });
      });
    }
  }
}
