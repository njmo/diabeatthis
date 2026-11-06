import 'package:flutter/material.dart';

import '../../../../../common/family/family_pairing_member.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/animated_reveal.dart';
import '../../widgets/settings_section_card.dart';

class SetupFamilyMembersList extends StatelessWidget {
  const SetupFamilyMembersList({
    super.key,
    required this.members,
    this.animatedMemberIds = const {},
  });
  final List<FamilyPairingMember> members;
  final Set<String> animatedMemberIds;

  @override
  Widget build(BuildContext context) => SettingsSectionCard(
    icon: Icons.people_outline,
    title: context.lang.setupLinkedAccounts,
    subtitle: context.lang.setupLinkedAccountsSource,
    children: [
      for (final member in members)
        AnimatedReveal(
          key: ValueKey(member.id),
          animate: animatedMemberIds.contains(member.id),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(member.displayName),
            subtitle: Text(switch (member.role) {
              FamilyMemberRole.child => context.lang.setupMemberChild,
              FamilyMemberRole.caregiver => context.lang.setupMemberCaregiver,
              FamilyMemberRole.managingCaregiver =>
                context.lang.setupMemberManagingCaregiver,
            }),
            trailing: Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
    ],
  );
}
