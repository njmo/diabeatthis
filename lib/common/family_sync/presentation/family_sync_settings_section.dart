import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../routing/form_bottom_sheet_route.dart';
import '../../widgets/settings_action_row.dart';
import 'family_sync_page.dart';

class FamilySyncSettingsSection extends StatelessWidget {
  const FamilySyncSettingsSection({super.key});
  @override
  Widget build(BuildContext context) => SettingsActionRow(
    icon: Icons.sync,
    title: context.lang.familySyncTitle,
    onTap: () => showFormBottomSheet<void>(context, const FamilySyncPage()),
  );
}
