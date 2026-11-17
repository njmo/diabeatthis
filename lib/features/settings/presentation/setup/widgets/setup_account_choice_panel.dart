import 'package:flutter/material.dart';

import '../../../../../common/auth/widgets/google_account_summary.dart';
import '../../../../../common/auth/widgets/google_sign_in_button.dart';
import '../../../../../common/l10n/language.dart';
import '../setup_wizard_controller.dart';
import 'setup_family_status_notice.dart';

class SetupAccountChoicePanel extends StatelessWidget {
  const SetupAccountChoicePanel({
    super.key,
    required this.controller,
    this.caregiverRequiresGoogle = false,
    this.showDescription = true,
  });
  final SetupWizardController controller;
  final bool caregiverRequiresGoogle;
  final bool showDescription;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.familyCareLocked || controller.state.familyMembersFailed)
          SetupFamilyStatusNotice(
            isPending: controller.familyMembershipPending &&
                !controller.state.familyMembersFailed,
            hasFailed: controller.state.familyMembersFailed,
            onRetry: controller.refreshFamilyMembers,
          ),
        if (controller.state.googleAccount != null)
          GoogleAccountSummary(
            account: controller.state.googleAccount!,
            onSignOut: controller.state.signingIn || controller.familyCareLocked
                ? null
                : controller.signOutGoogle,
          )
        else
          GoogleSignInButton(
            onPressed: controller.authentication?.isSupported == false
                ? null
                : controller.signInGoogle,
            busy: controller.state.signingIn,
          ),
        if (controller.authentication?.isSupported == false)
          Text(context.lang.setupGoogleUnavailablePlatform),
        if (controller.state.signInFailed)
          Text(
            context.lang.setupGoogleSignInFailed,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (!controller.state.signedIn && showDescription) ...[
          const SizedBox(height: 12),
          Text(
            caregiverRequiresGoogle
                ? context.lang.setupCaregiverGoogleRequired
                : context.lang.setupLocalAccountDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}
