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
  Widget build(BuildContext context) => secondary == null
      ? primary
      : Column(
          children: [
            primary,
            Icon(
              Icons.link_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            secondary!,
          ],
        );
}
