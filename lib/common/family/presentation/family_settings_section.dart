import 'package:flutter/material.dart';

import '../../family_chat/presentation/family_chat_settings_section.dart';
import '../../family_sync/presentation/family_sync_settings_section.dart';
import '../../l10n/language.dart';
import '../../routing/form_bottom_sheet_route.dart';
import '../../widgets/settings_action_row.dart';
import '../../widgets/settings_section_card.dart';
import 'family_management_page.dart';

class FamilySettingsSection extends StatelessWidget {
  const FamilySettingsSection({super.key});
  @override
  Widget build(BuildContext context) => SettingsSectionCard(
    icon: Icons.people_outline,
    title: context.lang.familyManagementTitle,
    subtitle: context.lang.familySettingsDescription,
    children: [
      SettingsActionRow(
        icon: Icons.manage_accounts_outlined,
        title: context.lang.familyManageAction,
        onTap: () => showFormBottomSheet<void>(
          context,
          const FamilyManagementPage(),
          initialContentHeight: 240,
        ),
      ),
      const FamilySyncSettingsSection(),
      const FamilyChatSettingsSection(),
    ],
  );
}
