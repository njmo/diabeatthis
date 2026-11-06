import 'package:diabeatthis/common/family/demo_family_pairing_repository.dart';
import 'package:diabeatthis/common/family/family_management_context.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/use_cases/create_family_invitation_use_case.dart';
import 'package:diabeatthis/common/family/use_cases/disconnect_family_member_use_case.dart';
import 'package:diabeatthis/common/family/use_cases/simulate_family_pairing_use_case.dart';
import 'package:diabeatthis/common/family/use_cases/watch_family_members_use_case.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in SetupDeviceMode.values) {
    for (final context in FamilyManagementContext.values) {
      test(
        '$mode disconnect policy in $context is enforced by use case and repository',
        () async {
          final repository = DemoFamilyPairingRepository();
          addTearDown(repository.dispose);
          final create = CreateFamilyInvitationUseCase(repository);
          final watch = WatchFamilyMembersUseCase(repository);
          final pair = SimulateFamilyPairingUseCase(repository);
          final disconnect = DisconnectFamilyMemberUseCase(repository);
          var members = <FamilyPairingMember>[];
          final subscription = watch(mode).listen((value) => members = value);
          addTearDown(subscription.cancel);
          await create(mode);
          pair(mode);
          final id = members.single.id;
          final allowed =
              mode == SetupDeviceMode.caregiver ||
              context == FamilyManagementContext.initialSetup;
          expect(disconnect.canDisconnect(mode, context), allowed);
          if (allowed) {
            await disconnect(mode, id, context);
            expect(members, isEmpty);
            pair(mode);
            expect(
              members,
              isEmpty,
              reason: 'Consumed invitations cannot reconnect removed members',
            );
            await create(mode);
            pair(mode);
            expect(members, hasLength(1));
            expect(members.single.id, isNot(id));
          } else {
            await expectLater(disconnect(mode, id, context), throwsStateError);
            await expectLater(
              repository.disconnectMember(mode, id, context),
              throwsStateError,
            );
            expect(members.single.id, id);
          }
        },
      );
    }
  }
}
