import 'package:flutter/material.dart';

import '../../../../common/auth/google_account.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/profile_avatar.dart';
import 'settings_section_card.dart';

class GoogleAccountCard extends StatelessWidget {
  const GoogleAccountCard({
    super.key,
    required this.signedIn,
    required this.onSignIn,
    required this.onSignOut,
    this.account,
    this.busy = false,
    this.failed = false,
    this.supported = true,
    this.demo = false,
  });
  final GoogleAccount? account;
  final bool signedIn;
  final bool busy;
  final bool failed;
  final bool supported;
  final bool demo;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) => SettingsSectionCard(
    icon: Icons.account_circle_outlined,
    title: context.lang.setupRequirementGoogle,
    leading: account == null
        ? null
        : ProfileAvatar(name: account!.label, photoUrl: account!.photoUrl),
    children: [
      if (signedIn) ...[
        Text(
          demo
              ? context.lang.setupSignedIn
              : (account?.label.isNotEmpty == true
                    ? account!.label
                    : context.lang.setupGoogleConnected),
        ),
        if (account?.email != null) Text(account!.email!),
        if (!demo)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: busy ? null : onSignOut,
              child: Text(context.lang.setupGoogleSignOut),
            ),
          ),
      ] else
        FilledButton.tonal(
          onPressed: busy || !supported ? null : onSignIn,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  demo
                      ? context.lang.setupSimulateSignIn
                      : context.lang.setupGoogleSignIn,
                ),
        ),
      if (!supported) Text(context.lang.setupGoogleUnavailablePlatform),
      if (failed) Text(context.lang.setupGoogleSignInFailed),
    ],
  );
}
