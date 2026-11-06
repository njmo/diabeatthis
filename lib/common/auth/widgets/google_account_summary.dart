import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../widgets/profile_avatar.dart';
import '../google_account.dart';
import 'google_brand_mark.dart';

class GoogleAccountSummary extends StatelessWidget {
  const GoogleAccountSummary({
    super.key,
    required this.account,
    this.onSignOut,
  });
  final GoogleAccount account;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ProfileAvatar(
                name: account.label,
                photoUrl: account.photoUrl,
                size: 52,
              ),
              const PositionedDirectional(
                end: -3,
                bottom: -3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: GoogleBrandMark(size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              context.lang.setupGoogleSignedInAs(account.label),
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: onSignOut,
            tooltip: context.lang.setupGoogleSignOut,
            icon: const Icon(Icons.link_off_outlined, size: 22),
            color: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
