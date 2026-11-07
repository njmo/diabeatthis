import 'package:flutter/material.dart';

class SettingsSectionLeading extends StatelessWidget {
  const SettingsSectionLeading({
    super.key,
    required this.child,
    this.backgroundColor,
  });
  final Widget child;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Center(child: child),
  );
}
