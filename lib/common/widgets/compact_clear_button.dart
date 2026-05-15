import 'package:flutter/material.dart';

class CompactClearButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  const CompactClearButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.size = 30,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: scheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(
              Icons.close,
              size: iconSize,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
