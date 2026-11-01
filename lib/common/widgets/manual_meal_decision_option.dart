import 'package:flutter/material.dart';

class ManualMealDecisionOption extends StatelessWidget {
  const ManualMealDecisionOption({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.1)
            : colors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? colors.primary : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(
            icon,
            color: selected ? colors.primary : colors.onSurfaceVariant,
          ),
          title: Text(label),
          trailing: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? colors.primary : colors.onSurfaceVariant,
          ),
          onTap: onPressed,
        ),
      ),
    );
  }
}
