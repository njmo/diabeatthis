import 'package:flutter/material.dart';

/// Reveals a newly inserted item without replaying when its stable key rebuilds.
class AnimatedReveal extends StatelessWidget {
  const AnimatedReveal({super.key, required this.child, this.animate = true});
  final Widget child;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final enabled = animate && !MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: enabled ? 0 : 1, end: 1),
      duration: enabled ? const Duration(milliseconds: 240) : Duration.zero,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: value,
          child: Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 10),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
