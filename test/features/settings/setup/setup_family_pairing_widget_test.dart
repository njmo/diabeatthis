import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_family_members_list.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_pairing_invitation_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  for (final mode in SetupDeviceMode.values) {
    testWidgets(
      '$mode shows refreshed codes and linked identity below the invitation',
      (tester) async {
        final draft =
            SetupWizardState(
                config: const DataSourceConfig.defaults(),
                language: applicationLanguageByCode('pl'),
                name: 'Child',
                nightscoutUrl: '',
                nightscoutToken: '',
              )
              ..step = 4
              ..mode = mode;
        await tester.pumpWidget(
          localizedMaterialApp(
            home: SetupWizard(
              initialState: draft,
              availability: const DataSourceOptionAvailability.none(),
            ),
          ),
        );
        await tester.tap(find.text('Symuluj logowanie Google'));
        await tester.pumpAndSettle();
        final firstId = draft.pairingInvitation!.id;
        expect(find.byType(SetupFamilyMembersList), findsNothing);
        await tester.ensureVisible(find.text('Symuluj parowanie'));
        await tester.tap(find.text('Symuluj parowanie'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pumpAndSettle();
        expect(find.byType(SetupFamilyMembersList), findsOneWidget);
        expect(
          find.text(
            mode == SetupDeviceMode.patient ? 'Alex Morgan' : 'Sam Morgan',
          ),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(find.byType(SetupFamilyMembersList)).dy,
          greaterThan(
            tester.getTopLeft(find.byType(SetupPairingInvitationCard)).dy,
          ),
        );
        await tester.ensureVisible(
          find.text(
            mode == SetupDeviceMode.patient
                ? 'Dodaj opiekuna'
                : 'Dodaj dziecko',
          ),
        );
        await tester.tap(
          find.text(
            mode == SetupDeviceMode.patient
                ? 'Dodaj opiekuna'
                : 'Dodaj dziecko',
          ),
        );
        await tester.pumpAndSettle();
        expect(draft.pairingInvitation!.id, isNot(firstId));
        expect(draft.familyMembers, hasLength(1));
        expect(draft.paired, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
