import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/status_info_card.dart';

class AiAuthorFundedNotice extends StatelessWidget {
  const AiAuthorFundedNotice({super.key});
  @override
  Widget build(BuildContext context) => StatusInfoCard(
    icon: Icons.favorite_border,
    title: context.lang.settingsAiAuthorFundedTitle,
    subtitle: context.lang.settingsAiAuthorFundedNotice,
  );
}
