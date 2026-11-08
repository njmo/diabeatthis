import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A quiet presence pulse; the label conveys the same state without color.
class ActivePresenceIndicator extends HookWidget {
  const ActivePresenceIndicator({
    super.key,
    required this.active,
    required this.label,
  });
  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bright = useState(true);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    useEffect(() {
      if (!active || reduceMotion) return null;
      final timer = Timer.periodic(
        const Duration(milliseconds: 900),
        (_) => bright.value = !bright.value,
      );
      return timer.cancel;
    }, [active, reduceMotion]);
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: AnimatedOpacity(
            opacity: !active || reduceMotion || bright.value ? 1 : .35,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: Icon(
              active ? Icons.circle : Icons.circle_outlined,
              size: 10,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    );
  }
}
