import 'dart:async';

import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_permission_gateway.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/regression/setup_live_services.dart';
import 'setup_account_choice_test.dart' show accountChoiceDraft;

class DelayedLogoutRepository extends SetupGoogleAuthenticationTestRepository {
  final logout = Completer<void>();
  @override
  Future<void> signOut() => logout.future;
}

class OrderedPermissionGateway implements SetupPermissionGateway {
  final checks = <Completer<bool>>[];
  @override
  Future<bool> check(SetupRequirement requirement) {
    if (requirement != SetupRequirement.notifications) {
      return Future.value(true);
    }
    final pending = Completer<bool>();
    checks.add(pending);
    return pending.future;
  }

  @override
  Future<bool> request(SetupRequirement requirement) async => true;
}

void main() {
  test(
    'mode cannot change during the pending local-account transition',
    () async {
      final auth = DelayedLogoutRepository();
      addTearDown(auth.dispose);
      final controller = SetupWizardController(
        accountChoiceDraft(),
        authentication: auth,
      );
      addTearDown(controller.dispose);
      final selecting = controller.continueWithoutGoogle();
      controller.setMode(SetupDeviceMode.caregiver);
      expect(controller.state.mode, SetupDeviceMode.patient);
      auth.logout.complete();
      await selecting;
      controller.setMode(SetupDeviceMode.caregiver);
      expect(controller.state.mode, SetupDeviceMode.caregiver);
    },
  );
  test(
    'an older status read cannot overwrite a newer permission refresh',
    () async {
      final permissions = OrderedPermissionGateway();
      final controller = SetupWizardController(
        accountChoiceDraft(),
        permissions: permissions,
      );
      addTearDown(controller.dispose);
      final older = controller.refreshPermissions();
      final newer = controller.refreshPermissions();
      expect(permissions.checks, hasLength(2));
      permissions.checks[1].complete(true);
      await newer;
      permissions.checks[0].complete(false);
      await older;
      expect(
        controller.state.granted,
        contains(SetupRequirement.notifications),
      );
    },
  );
}
