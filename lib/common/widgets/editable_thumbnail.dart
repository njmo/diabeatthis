import 'package:flutter/material.dart';

class EditableThumbnail extends StatelessWidget {
  const EditableThumbnail({
    super.key,
    required this.child,
    required this.tooltip,
    required this.onPressed,
    this.size = 76,
  });

  final Widget child;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                children: [
                  Center(child: child),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.surfaceContainerLowest,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
