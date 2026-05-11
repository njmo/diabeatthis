import 'package:flutter/material.dart';

class KeyboardAwareBottomSheet extends StatelessWidget {
  const KeyboardAwareBottomSheet({
    super.key,
    required this.header,
    required this.body,
    required this.actions,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.maxHeightFactor = 0.92,
  });

  final Widget header;
  final Widget body;
  final Widget actions;
  final EdgeInsets padding;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.viewInsets.bottom -
        mediaQuery.padding.top;
    final maxHeight = availableHeight * maxHeightFactor;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 8),
                Flexible(child: SingleChildScrollView(child: body)),
                const SizedBox(height: 12),
                actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
