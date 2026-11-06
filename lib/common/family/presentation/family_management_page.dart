import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_mode/application_device_mode.dart';
import '../../auth/google_authentication_providers.dart';
import '../../l10n/language.dart';
import '../../setup/domain/setup_feature.dart';
import '../family_providers.dart';
import 'secure_family_panel.dart';

class FamilyManagementPage extends ConsumerWidget {
  const FamilyManagementPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(googleAccountProvider).asData?.value;
    final mode = ref.watch(applicationDeviceModeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.lang.familyManagementTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: account == null || mode.isLoading || mode.hasError
              ? Text(context.lang.familyGoogleRequired)
              : SecureFamilyPanel(
                  key: ValueKey(account.uid),
                  repository: ref.watch(secureFamilyRepositoryProvider),
                  mode: mode.asData!.value == ApplicationDeviceMode.caregiver
                      ? SetupDeviceMode.caregiver
                      : SetupDeviceMode.patient,
                ),
        ),
      ),
    );
  }
}
