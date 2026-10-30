import 'package:flutter/material.dart';

class MissingIngredientIcon extends StatelessWidget {
  const MissingIngredientIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(color: colors.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.question_mark_rounded,
          size: size * 0.55,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
