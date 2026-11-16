import 'package:flutter/material.dart';

class ConnectedStatusCards extends StatelessWidget {
  const ConnectedStatusCards({
    super.key,
    required this.primary,
    this.secondary,
  });
  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    if (secondary == null) return primary;

    const linkColor = Color(0xFF00A3FF);
    return Column(
      children: [
        primary,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 2,
                height: 8,
                color: linkColor.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.link_rounded, size: 14, color: linkColor),
              const SizedBox(width: 4),
              Container(
                width: 2,
                height: 8,
                color: linkColor.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
        secondary!,
      ],
    );
  }
}
