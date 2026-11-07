import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_mode/application_device_mode.dart';
import '../../auth/google_authentication_providers.dart';
import '../../l10n/language.dart';
import '../../setup/domain/setup_feature.dart';
import '../../widgets/sheet_content_height_request.dart';
import '../../widgets/sheet_content_section_reporter.dart';
import '../family_providers.dart';
import 'family_loading_state.dart';
import 'secure_family_panel.dart';

class FamilyManagementPage extends ConsumerWidget {
  const FamilyManagementPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(googleAccountProvider);
    final account = accountState.asData?.value;
    final mode = ref.watch(applicationDeviceModeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.lang.familyManagementTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: SheetContentSectionReporter(
            section: SheetContentSection.body,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: accountState.isLoading || mode.isLoading
                  ? const FamilyLoadingState()
                  : account == null || mode.hasError
                  ? Text(context.lang.familyGoogleRequired)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SecureFamilyPanel(
                          key: ValueKey(account.uid),
                          repository: ref.watch(secureFamilyRepositoryProvider),
                          mode:
                              mode.asData!.value ==
                                  ApplicationDeviceMode.caregiver
                              ? SetupDeviceMode.caregiver
                              : SetupDeviceMode.patient,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
