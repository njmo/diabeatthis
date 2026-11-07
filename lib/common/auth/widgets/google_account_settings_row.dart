import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../widgets/profile_avatar.dart';
import '../google_account.dart';

class GoogleAccountSettingsRow extends StatelessWidget {
  const GoogleAccountSettingsRow({
    super.key,
    required this.account,
    this.onSignOut,
  });
  final GoogleAccount account;
  final VoidCallback? onSignOut;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ProfileAvatar(name: account.label, photoUrl: account.photoUrl, size: 40),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.label, style: Theme.of(context).textTheme.bodyLarge),
            if (account.email != null && account.email != account.label) ...[
              const SizedBox(height: 4),
              Text(
                account.email!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: context.lang.setupGoogleSignOut,
        onPressed: onSignOut,
        icon: const Icon(Icons.link_off_outlined),
      ),
    ],
  );
}
