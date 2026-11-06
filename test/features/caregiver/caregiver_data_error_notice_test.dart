import 'package:diabeatthis/features/caregiver/data/caregiver_nightscout_snapshot.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_refresh_state.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_visible_state_provider.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/caregiver_data_error_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  for (final cached in [false, true]) {
    testWidgets(
      'failed refresh is visible with cached data=$cached, without a manual refresh action',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              caregiverVisibleStateProvider.overrideWithValue(
                CaregiverRefreshState(
                  failed: true,
                  snapshot: cached
                      ? const CaregiverNightscoutSnapshot(
                          glucose: [],
                          targetFetched: true,
                          hasFailures: false,
                        )
                      : null,
                ),
              ),
            ],
            child: localizedMaterialApp(
              home: const Scaffold(body: CaregiverDataErrorNotice()),
            ),
          ),
        );
        expect(
          find.text(
            'Nie udało się odświeżyć danych Nightscout. Aplikacja automatycznie ponowi próbę.',
          ),
          findsOneWidget,
        );
        expect(find.byType(IconButton), findsNothing);
        expect(find.byIcon(Icons.refresh), findsNothing);
      },
    );
  }
  testWidgets('healthy refresh has no permanent status panel', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          caregiverVisibleStateProvider.overrideWithValue(
            const CaregiverRefreshState(),
          ),
        ],
        child: localizedMaterialApp(
          home: const Scaffold(body: CaregiverDataErrorNotice()),
        ),
      ),
    );
    expect(find.byType(Text), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
}
