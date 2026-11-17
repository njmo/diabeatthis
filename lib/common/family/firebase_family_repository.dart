import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../backend/authenticated_callable_transport.dart';
import '../setup/domain/setup_feature.dart';
import 'family_join_request.dart';
import 'family_pairing_invitation.dart';
import 'family_pairing_member.dart';
import 'family_status.dart';
import 'pairing_code.dart';
import 'secure_family_repository.dart';

/// No offline membership cache: authorization always comes from the server.
class FirebaseFamilyRepository
    with WidgetsBindingObserver
    implements SecureFamilyRepository {
  FirebaseFamilyRepository(this.transport) {
    status = StreamController<FamilyStatus>.broadcast(
      onListen: refresh,
      onCancel: stop,
    );
    WidgetsBinding.instance.addObserver(this);
  }
  final AuthenticatedCallableTransport transport;
  late final StreamController<FamilyStatus> status;
  Timer? timer;
  bool disposed = false;
  bool loading = false;
  bool active = true;
  int revision = 0;
  @override
  Stream<FamilyStatus> watchStatus() => status.stream;
  @override
  Stream<List<FamilyPairingMember>> watchMembers(SetupDeviceMode mode) =>
      watchStatus().map((value) => value.members);
  @override
  Future<FamilyPairingInvitation> createInvitation(SetupDeviceMode mode) async {
    if (mode != SetupDeviceMode.patient) {
      throw const CallableFailure('permission-denied');
    }
    final data = await transport.call('createFamilyInvite', {});
    return FamilyPairingInvitation(
      id: data['id'] as String,
      shortCode: data['shortCode'] as String?,
      expiresAt: data['expiresAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (data['expiresAt'] as num).toInt(),
            ),
      revision: (data['revision'] as num).toInt(),
      code: jsonEncode({
        'v': 1,
        'kind': 'diabeatthis-family',
        'inviteId': data['id'],
        'token': data['token'],
      }),
    );
  }

  @override
  Future<void> requestJoin(String qrCode) async {
    if (qrCode.length > 1024) throw const CallableFailure('invalid-argument');
    final value = jsonDecode(qrCode) as Map<String, dynamic>;
    if (value.length != 4 ||
        value['v'] != 1 ||
        value['kind'] != 'diabeatthis-family' ||
        value['inviteId'] is! String ||
        value['token'] is! String) {
      throw const CallableFailure('invalid-argument');
    }
    await transport.call('requestFamilyJoin', {
      'inviteId': value['inviteId'],
      'token': value['token'],
    });
    await refresh();
  }

  @override
  Future<void> requestJoinByCode(String code) async {
    if (!isValidPairingCode(code)) {
      throw const CallableFailure('invalid-argument');
    }
    await transport.call('requestFamilyJoinByCode', {
      'code': code.trim().toUpperCase(),
    });
    await refresh();
  }

  @override
  Future<void> decide(String invitationId, {required bool approve}) async {
    await transport.call('decideFamilyJoin', {
      'inviteId': invitationId,
      'approve': approve,
    });
    await refresh();
  }

  @override
  Future<void> disconnect(String memberId) async {
    await transport.call('disconnectFamilyMember', {'memberId': memberId});
    await refresh();
  }

  @override
  Future<void> finalizeSetup() =>
      transport.call('finalizeFamilySetup', {}).then((_) {});
  @override
  Future<void> refresh() async {
    if (disposed || !active || loading || !status.hasListener) return;
    timer?.cancel();
    loading = true;
    var failed = false;
    final session = revision;
    try {
      final data = await transport.call('getFamilyStatus', {});
      if (disposed || !active || session != revision) return;
      final pending = data['pending'] as Map?;
      status.add(
        FamilyStatus(
          members: (data['members'] as List).map((raw) {
            final member = Map<String, dynamic>.from(raw as Map);
            return FamilyPairingMember(
              id: member['id'] as String,
              displayName: member['displayName'] as String,
              role: FamilyMemberRole.values.byName(member['role'] as String),
              invitationId: member['invitationId'] as String,
              photoUrl: member['photoUrl'] as String?,
              canDisconnect: member['canDisconnect'] == true,
            );
          }).toList(),
          pending: pending == null
              ? null
              : FamilyJoinRequest(
                  email: pending['email'] as String? ?? '',
                  id: pending['id'] as String,
                  displayName: pending['displayName'] as String,
                  photoUrl: pending['photoUrl'] as String?,
                ),
          canLeave: data['canLeave'] == true,
          joinState: data['joinState'] as String?,
          invitationState: data['invitationState'] as String?,
          activeInvitationId: data['activeInvitationId'] as String?,
          activeInvitationRevision:
              (data['activeInvitationRevision'] as num?)?.toInt() ?? 0,
        ),
      );
    } catch (_) {
      failed = true;
      if (!disposed && active && session == revision) {
        status.addError(const CallableFailure('unavailable'));
      }
    } finally {
      loading = false;
      if (!disposed && active && status.hasListener) {
        timer = Timer(
          session == revision
              ? Duration(seconds: failed ? 10 : 3)
              : Duration.zero,
          refresh,
        );
      }
    }
  }

  void stop() {
    revision++;
    timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) {
      unawaited(refresh());
    } else {
      stop();
    }
  }

  void dispose() {
    disposed = true;
    stop();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(status.close());
  }
}
