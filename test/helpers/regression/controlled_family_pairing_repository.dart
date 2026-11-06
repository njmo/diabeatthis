import 'dart:async';

import 'package:diabeatthis/common/family/family_pairing_invitation.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/family_pairing_repository.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';

class ControlledFamilyPairingRepository implements FamilyPairingRepository {
  final requests = <Completer<FamilyPairingInvitation>>[];
  final channels = {
    for (final mode in SetupDeviceMode.values)
      mode: StreamController<List<FamilyPairingMember>>.broadcast(sync: true),
  };
  @override
  Future<FamilyPairingInvitation> createInvitation(SetupDeviceMode mode) {
    final request = Completer<FamilyPairingInvitation>();
    requests.add(request);
    return request.future;
  }

  @override
  Stream<List<FamilyPairingMember>> watchMembers(SetupDeviceMode mode) =>
      channels[mode]!.stream;
  Future<void> dispose() async {
    for (final channel in channels.values) {
      await channel.close();
    }
  }
}
