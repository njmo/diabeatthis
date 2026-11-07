import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/auth/google_authentication_providers.dart';
import '../../../../common/auth/widgets/google_account_settings_row.dart';
import '../../../../common/auth/widgets/google_brand_mark.dart';
import '../../../../common/auth/widgets/google_sign_in_button.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/settings_section_card.dart';
import '../../../../common/widgets/settings_section_leading.dart';

class GoogleAccountSettingsSection extends HookConsumerWidget {
  const GoogleAccountSettingsSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(googleAuthenticationRepositoryProvider);
    final account = ref.watch(googleAccountProvider);
    final busy = useState(false);
    final failed = useState(false);
    Future<void> run(Future<void> Function() action) async {
      if (busy.value) return;
      busy.value = true;
      failed.value = false;
      try {
        await action();
      } catch (_) {
        if (context.mounted) failed.value = true;
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    final signedIn = account.asData?.value;
    final working = busy.value || account.isLoading;
    return SettingsSectionCard(
      icon: Icons.account_circle_outlined,
      leading: const SettingsSectionLeading(
        backgroundColor: Colors.white,
        child: GoogleBrandMark(size: 24),
      ),
      title: context.lang.setupRequirementGoogle,
      children: [
        if (signedIn != null)
          GoogleAccountSettingsRow(
            account: signedIn,
            onSignOut: working ? null : () => run(repository.signOut),
          )
        else if (!account.isLoading)
          GoogleSignInButton(
            onPressed: repository.isSupported && !working
                ? () => run(() async {
                    await repository.signIn();
                  })
                : null,
            busy: working,
          ),
        if (working && (signedIn != null || account.isLoading))
          const LinearProgressIndicator(),
        if (!repository.isSupported)
          Text(context.lang.setupGoogleUnavailablePlatform),
        if (failed.value || account.hasError)
          Text(context.lang.setupGoogleSignInFailed),
      ],
    );
  }
}
