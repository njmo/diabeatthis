import 'package:flutter/material.dart';

import 'icon_choice_button.dart';

/// Shared two-action presentation used by meal start and caregiver invitations.
class IconChoicePair extends StatelessWidget {
  const IconChoicePair({
    super.key,
    required this.firstIcon,
    required this.firstLabel,
    required this.onFirst,
    required this.secondIcon,
    required this.secondLabel,
    required this.onSecond,
  });

  final IconData firstIcon, secondIcon;
  final String firstLabel, secondLabel;
  final VoidCallback? onFirst, onSecond;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: IconChoiceButton(
              icon: firstIcon,
              label: firstLabel,
              onPressed: onFirst,
              emphasized: true,
            ),
          ),
          const VerticalDivider(width: 1, indent: 24, endIndent: 24),
          Expanded(
            child: IconChoiceButton(
              icon: secondIcon,
              label: secondLabel,
              onPressed: onSecond,
            ),
          ),
        ],
      ),
    ),
  );
}
