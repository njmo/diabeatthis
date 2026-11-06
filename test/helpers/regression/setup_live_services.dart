import 'dart:async';

import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_repository.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_permission_gateway.dart';

class SetupGoogleAuthenticationTestRepository
    implements GoogleAuthenticationRepository {
  @override
  bool get isSupported => true;
  final accounts = StreamController<GoogleAccount?>.broadcast(sync: true);
  Completer<GoogleAccount?>? pending;
  GoogleAccount? result;
  int calls = 0;
  @override
  Stream<GoogleAccount?> watchAccount() => accounts.stream;
  @override
  Future<GoogleAccount?> signIn() async {
    calls++;
    if (pending != null) return pending!.future;
    if (result != null) accounts.add(result);
    return result;
  }

  @override
  Future<void> signOut() async {
    accounts.add(null);
  }

  Future<void> dispose() => accounts.close();
}

class SetupPermissionTestGateway implements SetupPermissionGateway {
  final granted = <SetupRequirement>{};
  final requests = <SetupRequirement>[];
  Completer<bool>? pendingCheck;
  bool allow = true;
  @override
  Future<bool> check(SetupRequirement requirement) async => pendingCheck == null
      ? granted.contains(requirement)
      : pendingCheck!.future;
  @override
  Future<bool> request(SetupRequirement requirement) async {
    requests.add(requirement);
    if (allow) granted.add(requirement);
    return allow;
  }
}
