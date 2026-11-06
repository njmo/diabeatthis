import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_feature_help_sheet.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_feature_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

SetupWizardState familySharingDraft() => SetupWizardState(
  config: const DataSourceConfig.defaults(),
  language: applicationLanguageByCode('pl'),
  name: 'Child',
  nightscoutUrl: '',
  nightscoutToken: '',
);

void main() {
  test(
    'family sharing and chat use one mode-scoped selection and pairing dependency',
    () {
      final controller = SetupWizardController(familySharingDraft());
      addTearDown(controller.dispose);
      expect(controller.state.shareData, isTrue);
      controller.select(SetupFeatureId.familyChat, false);
      expect(controller.state.shareData, isFalse);
      expect(controller.modules, isNot(contains(SetupModule.family)));
      controller.select(SetupFeatureId.familyChat, true);
      expect(controller.state.shareData, isTrue);
      expect(
        controller.requirements.keys,
        containsAll([
          SetupRequirement.googleAccount,
          SetupRequirement.familyPairing,
          SetupRequirement.internet,
          SetupRequirement.notifications,
        ]),
      );
      controller.goTo(4);
      controller.skipModule();
      expect(controller.state.shareData, isFalse);
      expect(
        controller.state.selected,
        isNot(contains(SetupFeatureId.familyChat)),
      );
      controller.setMode(SetupDeviceMode.caregiver);
      expect(controller.state.shareData, isTrue);
      controller.setMode(SetupDeviceMode.patient);
      expect(controller.state.shareData, isFalse);
    },
  );
  testWidgets(
    'family sharing lives in Features with independent help and is absent from Data',
    (tester) async {
      final draft = familySharingDraft()..step = 1;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: SetupWizard(
            initialState: draft,
            availability: const DataSourceOptionAvailability.none(),
          ),
        ),
      );
      final familyTile = find.byWidgetPredicate(
        (widget) =>
            widget is SetupFeatureTile &&
            widget.feature.id == SetupFeatureId.familyChat,
      );
      await tester.ensureVisible(familyTile);
      expect(
        find.descendant(
          of: familyTile,
          matching: find.text('Udostępnianie danych rodzinie'),
        ),
        findsOneWidget,
      );
      final info = find.descendant(
        of: familyTile,
        matching: find.byTooltip('Informacje o funkcji'),
      );
      await tester.ensureVisible(info);
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.byType(SetupFeatureHelpSheet), findsOneWidget);
      expect(
        find.textContaining('automatycznie synchronizowane z Firebase'),
        findsOneWidget,
      );
      expect(
        find.textContaining('komunikator dziecko–opiekun'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Składniki edytuje wyłącznie dziecko'),
        findsOneWidget,
      );
      expect(draft.shareData, isTrue);
      await tester.ensureVisible(find.text('Rozumiem'));
      await tester.tap(find.text('Rozumiem'));
      await tester.pumpAndSettle();
      final toggle = find.descendant(
        of: familyTile,
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(draft.shareData, isFalse);
      final wizard = tester.state<SetupWizardViewState>(
        find.byType(SetupWizard),
      );
      wizard.controller.goTo(2);
      await tester.pumpAndSettle();
      expect(find.text('Udostępnianie danych rodzinie'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
