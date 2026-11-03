import 'package:diabeatthis/app/event/task/task_event_handler.dart';
import 'package:diabeatthis/common/events/data/task/task_state_synchronization_payload.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/features/dashboard/data/providers/old_reading_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/device_status_dashboard.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/aaps_carbs_request_episode_store_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/aaps_carbs_request_episode_store.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/low_treatment_suggestion_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/device_status_factory.dart';
import '../../../../helpers/localized_material_app.dart';

void main() {
  final at = DateTime(2026, 11, 3, 16);

  for (final replay in [false, true]) {
    testWidgets(
      'fulfilled request disappears from dashboard despite positive AAPS status; replay=$replay',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesAapsCarbsRequestEpisodeStore(
          loadPreferences: () async => prefs,
        );
        final id = '${at.microsecondsSinceEpoch}:request';
        await store.acceptStatus(at, 8);
        await store.start(id);
        final status = testDeviceStatus(
          externalId: 'request',
          source: DeviceStatusSource.aaps,
          date: at,
          iob: 0,
          cob: 0,
          tick: '0',
          bg: 90,
          carbsReq: 8,
          carbsReqWithin: 5,
        ).copyWith(suggestedAt: at);
        TaskEventHandler? handler;
        Future<void> render() async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPrefsProvider.overrideWith((_) async => prefs),
                aapsCarbsRequestEpisodeStoreProvider.overrideWithValue(store),
                isReadingOldProvider.overrideWithValue(false),
              ],
              child: localizedMaterialApp(
                home: Scaffold(
                  body: Consumer(
                    builder: (context, ref, _) {
                      handler = TaskEventHandler(ref);
                      return DeviceStatusDashboard(deviceStatus: status);
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await render();
        expect(find.byType(LowTreatmentSuggestionCard), findsOneWidget);
        // The foreground writes this only after matching the required consumed carbs.
        await store.acknowledge(id);
        await store.markNotificationCancelled();
        handler!.handle(
          const TaskStateSynchronizationPayload.carbsRequestChanged()
              .toTaskEventJson(),
        );
        expect((await store.load()).acknowledged, isTrue);
        if (replay) {
          // Rebuilding the dashboard with the same AAPS request must not rearm it.
          await tester.pumpWidget(const SizedBox.shrink());
        }
        await render();
        expect(
          find.byType(LowTreatmentSuggestionCard),
          findsNothing,
          reason:
              'The acknowledged request must stay hidden even while the last AAPS snapshot has carbsReq=8.',
        );
      },
    );
  }

  testWidgets(
    'a new episode after AAPS withdraws the previous request appears again',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesAapsCarbsRequestEpisodeStore(
        loadPreferences: () async => prefs,
      );
      await store.acceptStatus(at, 8);
      await store.start('${at.microsecondsSinceEpoch}:old');
      await store.acknowledge('${at.microsecondsSinceEpoch}:old');
      await store.clear();
      final next = at.add(const Duration(minutes: 5));
      await store.acceptStatus(next, 6);
      await store.start('${next.microsecondsSinceEpoch}:new');
      expect((await store.load()).acknowledged, isFalse);
      final status = testDeviceStatus(
        externalId: 'new',
        source: DeviceStatusSource.aaps,
        date: next,
        iob: 0,
        cob: 0,
        tick: '0',
        bg: 90,
        carbsReq: 6,
        carbsReqWithin: 5,
      ).copyWith(suggestedAt: next);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWith((_) async => prefs),
            aapsCarbsRequestEpisodeStoreProvider.overrideWithValue(store),
            isReadingOldProvider.overrideWithValue(false),
          ],
          child: localizedMaterialApp(
            home: Scaffold(body: DeviceStatusDashboard(deviceStatus: status)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LowTreatmentSuggestionCard), findsOneWidget);
    },
  );
}
