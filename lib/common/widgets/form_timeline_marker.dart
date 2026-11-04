import 'package:flutter/material.dart';

enum FormTimelineStatus { pending, active, completed }

class FormTimelineMarker extends StatelessWidget {
  const FormTimelineMarker({
    super.key,
    required this.status,
    this.number,
    this.diameter,
    this.optional = false,
  });
  final FormTimelineStatus status;
  final int? number;
  final double? diameter;
  final bool optional;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = status == FormTimelineStatus.active;
    final completed = status == FormTimelineStatus.completed;
    final size = diameter ?? (active ? 26.0 : 20.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: optional && !completed
            ? Border.all(color: colors.outline, width: 1.5)
            : null,
        color: completed
            ? const Color(0xFF2E7D32)
            : active
            ? colors.primary
            : optional
            ? Colors.transparent
            : colors.surfaceContainerHighest,
      ),
      alignment: Alignment.center,
      child: completed
          ? Icon(
              Icons.check,
              size: diameter == null ? 14 : size * .65,
              color: Colors.white,
            )
          : number == null
          ? optional
                ? Icon(
                    Icons.add,
                    size: size * .55,
                    color: active ? colors.onPrimary : colors.onSurfaceVariant,
                  )
                : null
          : Text(
              '$number',
              style: TextStyle(
                fontSize: active ? 14 : 11,
                fontWeight: FontWeight.w600,
                color: active ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
    );
  }
}
