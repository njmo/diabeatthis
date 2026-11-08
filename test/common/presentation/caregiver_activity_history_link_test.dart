import 'package:diabeatthis/common/family_sync/presentation/models/family_activity_log_details.dart';
import 'package:diabeatthis/common/presentation/details/activity_log_preview_controller.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_log_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'family_collection_fixtures.dart';

void main() {
  testWidgets(
    'caregiver session uses family history callback without local data',
    (tester) async {
      final state = familyActivityLogDetails(familyCollectionFixtures(), 6)!;
      var opened = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith(
              (_) => throw StateError('Patient database accessed'),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: ActivityLogBody.controlled(
                controller: CaregiverActivityLogPreviewController(
                  state,
                  onOpenActivity: () => opened++,
                ),
                onTimestampSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final history = find.widgetWithIcon(TextButton, Icons.history_rounded);
      expect(history, findsOneWidget);
      await tester.tap(history);
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
