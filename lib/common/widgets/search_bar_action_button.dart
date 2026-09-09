import 'package:flutter/material.dart';

class SearchBarActionButton extends StatelessWidget {
  final Widget icon;
  final String? label;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  const SearchBarActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 48,
    this.label,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: label == null ? size : null,
    height: size,
    child: IconButton.outlined(
      tooltip: tooltip,
      icon: label == null
          ? icon
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 6),
                Text(label!, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: onPressed,
    ),
  );
}
