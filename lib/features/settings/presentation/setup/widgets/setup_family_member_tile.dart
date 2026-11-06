import 'package:flutter/material.dart';

import '../../../../../common/family/family_pairing_member.dart';
import '../../../../../common/l10n/language.dart';

class SetupFamilyMemberTile extends StatelessWidget {
  const SetupFamilyMemberTile({
    super.key,
    required this.member,
    this.onDisconnect,
    this.disconnecting = false,
  });
  final FamilyPairingMember member;
  final VoidCallback? onDisconnect;
  final bool disconnecting;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.account_circle_outlined),
    title: Text(member.displayName),
    subtitle: Text(switch (member.role) {
      FamilyMemberRole.child => context.lang.setupMemberChild,
      FamilyMemberRole.caregiver => context.lang.setupMemberCaregiver,
      FamilyMemberRole.managingCaregiver =>
        context.lang.setupMemberManagingCaregiver,
    }),
    trailing: disconnecting
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: context.lang.setupDisconnecting,
            ),
          )
        : onDisconnect != null
        ? IconButton(
            tooltip: context.lang.setupDisconnectMember(member.displayName),
            onPressed: onDisconnect,
            icon: const Icon(Icons.link_off),
          )
        : Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
  );
}
