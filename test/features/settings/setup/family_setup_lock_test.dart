import 'dart:async';

import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../common/family/family_settings_sheet_loading_test.dart'
    show LoadingFamilyRepository;
import '../../../helpers/regression/setup_live_services.dart';

class LockingFamilyRepository extends LoadingFamilyRepository {
  @override
  Stream<List<FamilyPairingMember>> watchMembers(SetupDeviceMode mode) =>
      statuses.stream.map((status) => status.members);
}

void main() {
  test(
    'only authoritative disconnect unlocks family, not skip signout loading or error',
    () async {
      final repository = LockingFamilyRepository();
      final state = SetupWizardState(
        config: const DataSourceConfig.defaults(),
        language: applicationLanguageByCode('en'),
        name: 'Child',
        nightscoutUrl: '',
        nightscoutToken: '',
      );
      final controller = SetupWizardController(
        state,
        familyRepository: repository,
      );
      controller.simulateSignIn();
      await Future<void>.delayed(Duration.zero);
      expect(controller.familyCareLocked, isTrue);
      repository.statuses.add(
        const FamilyStatus(
          members: [
            FamilyPairingMember(
              id: 'parent',
              displayName: 'Parent',
              role: FamilyMemberRole.caregiver,
              invitationId: 'invite',
            ),
          ],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.familyCareLocked, isTrue);
      state.step = SetupStep.configuration.index;
      state.moduleIndex = controller.modules.indexOf(SetupModule.family);
      expect(controller.canSkipCurrentModule, isFalse);
      controller.select(SetupFeatureId.familyChat, false);
      controller.skipModule();
      await controller.continueWithoutGoogle();
      expect(state.selected, contains(SetupFeatureId.familyChat));
      expect(state.signedIn, isTrue);
      repository.statuses.addError(StateError('Offline'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.familyCareLocked, isTrue);
      controller.select(SetupFeatureId.familyChat, false);
      expect(state.selected, contains(SetupFeatureId.familyChat));
      controller.refreshFamilyMembers();
      expect(controller.familyCareLocked, isTrue);
      await Future<void>.delayed(Duration.zero);
      repository.statuses.add(const FamilyStatus());
      await Future<void>.delayed(Duration.zero);
      expect(controller.familyCareLocked, isFalse);
      controller.select(SetupFeatureId.familyChat, false);
      expect(state.selected, isNot(contains(SetupFeatureId.familyChat)));
      controller.dispose();
      await repository.statuses.close();
    },
  );
  test(
    'live Google cannot be removed before the first authoritative family status',
    () async {
      final repository = LockingFamilyRepository();
      final auth = SetupGoogleAuthenticationTestRepository();
      final state = SetupWizardState(
        config: const DataSourceConfig.defaults(),
        language: applicationLanguageByCode('en'),
        name: 'Child',
        nightscoutUrl: '',
        nightscoutToken: '',
      );
      final controller = SetupWizardController(
        state,
        familyRepository: repository,
        authentication: auth,
      );
      auth.accounts.add(const GoogleAccount(uid: 'child'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.familyCareLocked, isTrue);
      await controller.signOutGoogle();
      await controller.continueWithoutGoogle();
      expect(state.signedIn, isTrue);
      repository.statuses.addError(StateError('Offline before first response'));
      await Future<void>.delayed(Duration.zero);
      await controller.signOutGoogle();
      expect(state.signedIn, isTrue);
      repository.statuses.add(const FamilyStatus());
      await Future<void>.delayed(Duration.zero);
      expect(controller.familyCareLocked, isFalse);
      await controller.signOutGoogle();
      expect(state.signedIn, isFalse);
      controller.dispose();
      await repository.statuses.close();
      await auth.dispose();
    },
  );
}
