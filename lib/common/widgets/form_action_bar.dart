import 'package:flutter/material.dart';

/// Keeps form actions on an opaque surface and away from system navigation.
class FormActionBar extends StatelessWidget {
  const FormActionBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: child,
      ),
    ),
  );
}
