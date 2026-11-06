import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/auth/google_authentication_providers.dart';
import 'google_account_card.dart';

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

    return GoogleAccountCard(
      account: account.asData?.value,
      signedIn: account.asData?.value != null,
      busy: busy.value || account.isLoading,
      failed: failed.value || account.hasError,
      supported: repository.isSupported,
      onSignIn: () => run(() async {
        await repository.signIn();
      }),
      onSignOut: () => run(repository.signOut),
    );
  }
}
