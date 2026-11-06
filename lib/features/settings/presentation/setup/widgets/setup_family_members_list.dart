import 'package:flutter/material.dart';

import '../../../../../common/family/family_pairing_member.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/animated_reveal.dart';
import 'setup_family_member_tile.dart';

class SetupFamilyMembersList extends StatelessWidget {
  const SetupFamilyMembersList({
    super.key,
    required this.members,
    this.animatedMemberIds = const {},
    this.disconnectingMembers = const {},
    this.onDisconnect,
  });
  final List<FamilyPairingMember> members;
  final Set<String> animatedMemberIds;
  final Set<String> disconnectingMembers;
  final ValueChanged<FamilyPairingMember>? onDisconnect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.lang.setupLinkedAccounts,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Text(
        context.lang.setupLinkedAccountsSource,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      for (final member in members)
        AnimatedReveal(
          key: ValueKey(member.id),
          animate: animatedMemberIds.contains(member.id),
          child: SetupFamilyMemberTile(
            member: member,
            disconnecting: disconnectingMembers.contains(member.id),
            onDisconnect: onDisconnect == null
                ? null
                : () => onDisconnect!(member),
          ),
        ),
    ],
  );
}
