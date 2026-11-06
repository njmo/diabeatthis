import 'package:diabeatthis/common/family/family_pairing_invitation.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/regression/controlled_family_pairing_repository.dart';

SetupWizardState familyDraft() => SetupWizardState(
  config: const DataSourceConfig.defaults(),
  language: applicationLanguageByCode('pl'),
  name: 'Child',
  nightscoutUrl: '',
  nightscoutToken: '',
)..step = 4;
const member = FamilyPairingMember(
  id: 'guardian',
  displayName: 'Backend guardian',
  role: FamilyMemberRole.caregiver,
  invitationId: 'first',
);
const invitation = FamilyPairingInvitation(id: 'first', code: 'DEMO-1');

void main() {
  late ControlledFamilyPairingRepository repository;
  late SetupWizardController controller;
  setUp(() {
    repository = ControlledFamilyPairingRepository();
    controller = SetupWizardController(
      familyDraft(),
      familyRepository: repository,
    );
    addTearDown(repository.dispose);
    addTearDown(controller.dispose);
  });

  test(
    'pairing status and displayed identity are read from membership snapshots',
    () async {
      controller.simulateSignIn();
      repository.requests.single.complete(invitation);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.familyMembers, isEmpty);
      expect(controller.state.paired, isFalse);
      repository.channels[SetupDeviceMode.patient]!.add([member]);
      expect(
        controller.state.familyMembers.single.displayName,
        'Backend guardian',
      );
      expect(controller.state.paired, isTrue);
      expect(controller.invitationUsed, isTrue);
      repository.channels[SetupDeviceMode.patient]!.add([]);
      expect(controller.state.paired, isFalse);
      expect(controller.state.configured.contains(SetupModule.family), isFalse);
    },
  );

  test(
    'code renewal cannot hide a membership error or mark pairing verified',
    () async {
      controller.simulateSignIn();
      repository.requests.single.complete(invitation);
      await Future<void>.delayed(Duration.zero);
      repository.channels[SetupDeviceMode.patient]!.add([member]);
      repository.channels[SetupDeviceMode.patient]!.addError(
        StateError('Membership unavailable'),
      );
      expect(controller.state.familyMembersFailed, isTrue);
      expect(controller.state.familyMembers, isEmpty);
      expect(controller.next(), isFalse);
      final renewal = controller.generatePairingInvitation();
      repository.requests.last.complete(
        const FamilyPairingInvitation(id: 'second', code: 'DEMO-2'),
      );
      await renewal;
      expect(controller.state.familyMembersFailed, isTrue);
      expect(controller.state.paired, isFalse);
      repository.channels[SetupDeviceMode.patient]!.add([member]);
      expect(controller.state.familyMembersFailed, isFalse);
      expect(controller.state.paired, isTrue);
    },
  );

  test(
    'late invitation and membership results do not cross device modes',
    () async {
      controller.simulateSignIn();
      controller.setMode(SetupDeviceMode.caregiver);
      controller.simulateSignIn();
      repository.requests.first.complete(invitation);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.pairingInvitation, isNull);
      expect(controller.state.generatingInvitation, isTrue);
      repository.channels[SetupDeviceMode.patient]!.add([member]);
      expect(controller.state.familyMembers, isEmpty);
      repository.requests.last.complete(
        const FamilyPairingInvitation(id: 'caregiver', code: 'DEMO-NEW'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.pairingInvitation!.id, 'caregiver');
      expect(controller.state.generatingInvitation, isFalse);
    },
  );

  test(
    'failed code creation is reported independently and can be retried',
    () async {
      controller.simulateSignIn();
      repository.requests.single.completeError(StateError('Unavailable'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.invitationFailed, isTrue);
      expect(controller.state.familyMembersFailed, isFalse);
      final retry = controller.generatePairingInvitation();
      repository.requests.last.complete(invitation);
      await retry;
      expect(controller.state.invitationFailed, isFalse);
      expect(controller.state.pairingInvitation, invitation);
    },
  );

  test(
    'an invitation completing after disposal cannot publish state',
    () async {
      final localRepository = ControlledFamilyPairingRepository();
      addTearDown(localRepository.dispose);
      final localController = SetupWizardController(
        familyDraft(),
        familyRepository: localRepository,
      );
      localController.simulateSignIn();
      localController.dispose();
      localRepository.requests.single.complete(invitation);
      await Future<void>.delayed(Duration.zero);
      expect(localController.state.pairingInvitation, isNull);
    },
  );
}
