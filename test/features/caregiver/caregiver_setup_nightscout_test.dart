import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/setup/domain/setup_configuration_field.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/common/setup/domain/validate_setup_module_use_case.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/setup_live_services.dart';
import '../settings/setup/setup_account_choice_test.dart'
    show accountChoiceDraft;

void main() {
  test(
    'caregiver always validates read-only Nightscout even after selecting local patient sources',
    () async {
      final auth = SetupGoogleAuthenticationTestRepository();
      addTearDown(auth.dispose);
      final draft = accountChoiceDraft()
        ..config = const DataSourceConfig(
          bgSource: BgSource.aaps,
          treatmentsSource: TreatmentsSource.aaps,
          pumpStatusSource: PumpStatusSource.aaps,
          historySource: HistorySource.local,
          mirrorToLocal: false,
        );
      final checks = <bool>[];
      final controller = SetupWizardController(
        draft,
        authentication: auth,
        checkNightscoutConnection: (url, token, writes) async {
          checks.add(writes);
          return SetupNightscoutVerification.readWriteVerified;
        },
      );
      addTearDown(controller.dispose);
      auth.accounts.add(
        const GoogleAccount(uid: 'parent', displayName: 'Parent'),
      );
      controller.setMode(SetupDeviceMode.caregiver);
      controller.goTo(SetupStep.configuration.index);
      draft.moduleIndex = controller.modules.indexOf(SetupModule.nightscout);
      expect(
        controller.requiredConfiguration.containsKey(
          SetupConfigurationField.nightscoutUrl,
        ),
        isTrue,
      );
      expect(
        controller.requiredConfiguration.containsKey(
          SetupConfigurationField.nightscoutToken,
        ),
        isFalse,
      );
      expect(controller.canSkipCurrentModule, isFalse);
      controller.skipModule();
      expect(controller.module, SetupModule.nightscout);
      expect(await controller.validateAndNext(), isFalse);
      controller.setNightscout('https://nightscout.test', 'read-token');
      expect(await controller.validateAndNext(), isTrue);
      expect(checks, [false]);
      expect(draft.currentStep, SetupStep.configuration);
      expect(controller.module, controller.modules[1]);
      expect(draft.configured, contains(SetupModule.nightscout));
    },
  );
}
