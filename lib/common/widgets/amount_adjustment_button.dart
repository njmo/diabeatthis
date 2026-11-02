import 'package:flutter/material.dart';

/// Keeps all four adjustments reachable beside the editable amount on a phone.
class AmountAdjustmentButton extends StatelessWidget {
  const AmountAdjustmentButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 48,
      child: IconButton.filledTonal(
        style: IconButton.styleFrom(
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon != null
            ? Icon(icon)
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: emphasized ? const TextStyle(fontSize: 20) : null,
                ),
              ),
      ),
    );
  }
}
