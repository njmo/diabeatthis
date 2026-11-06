import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_family_members_list.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_family_pairing_panel.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_pairing_success.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets(
      'pairing reveals membership with reduced motion $reducedMotion',
      (tester) async {
        final state = SetupWizardState(
          config: const DataSourceConfig.defaults(),
          language: applicationLanguageByCode('pl'),
          name: 'Child',
          nightscoutUrl: '',
          nightscoutToken: '',
        );
        final controller = SetupWizardController(state);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          localizedMaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reducedMotion),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SetupFamilyPairingPanel(controller: controller),
                ),
              ),
            ),
          ),
        );
        controller.simulateSignIn();
        await tester.pumpAndSettle();
        final firstId = state.pairingInvitation!.id;
        controller.simulatePairing();
        await tester.pump();
        expect(state.paired, isTrue);
        expect(find.text('Wygeneruj nowy kod'), findsNothing);
        if (!reducedMotion) {
          expect(find.byType(SetupPairingSuccess), findsOneWidget);
          expect(find.byType(SetupFamilyMembersList), findsNothing);
          await tester.pump(const Duration(milliseconds: 499));
          expect(find.byType(SetupFamilyMembersList), findsNothing);
          await tester.pump(const Duration(milliseconds: 1));
          expect(find.text('Dodaj opiekuna'), findsOneWidget);
          expect(find.byType(SetupFamilyMembersList), findsNothing);
          await tester.pump(const Duration(milliseconds: 240));
        }
        await tester.pumpAndSettle();
        expect(find.byType(SetupFamilyMembersList), findsOneWidget);
        await tester.ensureVisible(find.text('Dodaj opiekuna'));
        await tester.tap(find.text('Dodaj opiekuna'));
        await tester.pumpAndSettle();
        expect(state.pairingInvitation!.id, isNot(firstId));
        expect(find.byType(SetupFamilyMembersList), findsOneWidget);
        controller.simulatePairing();
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
