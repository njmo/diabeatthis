import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_family_pairing_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  for (final mode in SetupDeviceMode.values) {
    testWidgets('$mode uses the correct side of mock QR pairing', (
      tester,
    ) async {
      final state = SetupWizardState(
        config: const DataSourceConfig.defaults(),
        language: applicationLanguageByCode('pl'),
        name: 'Demo',
        nightscoutUrl: '',
        nightscoutToken: '',
      )..mode = mode;
      final controller = SetupWizardController(state);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SetupFamilyPairingPanel(controller: controller),
            ),
          ),
        ),
      );
      controller.simulateSignIn();
      await tester.pumpAndSettle();
      final scanning = mode == SetupDeviceMode.caregiver;
      expect(
        find.byIcon(Icons.qr_code_scanner),
        scanning ? findsOneWidget : findsNothing,
      );
      expect(
        find.byIcon(Icons.qr_code_2),
        scanning ? findsNothing : findsOneWidget,
      );
      expect(
        find.text(state.pairingInvitation!.code),
        scanning ? findsNothing : findsOneWidget,
      );
      if (scanning) expect(find.text('Zeskanuj kod dziecka'), findsOneWidget);
      await tester.tap(find.text('Symuluj parowanie'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pumpAndSettle();
      expect(
        find.text(scanning ? 'Sam Morgan' : 'Alex Morgan'),
        findsOneWidget,
      );
      final addLabel = scanning ? 'Dodaj dziecko' : 'Dodaj opiekuna';
      await tester.ensureVisible(find.text(addLabel));
      await tester.tap(find.text(addLabel));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.qr_code_scanner),
        scanning ? findsOneWidget : findsNothing,
      );
      expect(
        find.text(state.pairingInvitation!.code),
        scanning ? findsNothing : findsOneWidget,
      );
      expect(state.familyMembers, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}
