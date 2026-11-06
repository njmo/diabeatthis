import 'package:flutter/material.dart';

import '../l10n/language.dart';

/// A single row with native horizontal scrolling and visible overflow controls.
class ScrollableChipRail extends StatefulWidget {
  const ScrollableChipRail({super.key, required this.children});
  final List<Widget> children;

  @override
  State<ScrollableChipRail> createState() => ScrollableChipRailState();
}

class ScrollableChipRailState extends State<ScrollableChipRail> {
  final controller = ScrollController();
  bool before = false;
  bool after = false;

  void refresh() {
    if (!mounted || !controller.hasClients) return;
    final nextBefore = controller.position.extentBefore > 1;
    final nextAfter = controller.position.extentAfter > 1;
    if (before == nextBefore && after == nextAfter) return;
    setState(() {
      before = nextBefore;
      after = nextAfter;
    });
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(refresh);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void move(double direction) {
    final target =
        (controller.offset +
                direction * controller.position.viewportDimension * .7)
            .clamp(0.0, controller.position.maxScrollExtent);
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
              return false;
            },
            child: ListView.separated(
              controller: controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: widget.children.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, index) => Center(child: widget.children[index]),
            ),
          ),
          if (before)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.surfaceContainerLowest,
                      colors.surfaceContainerLowest.withValues(alpha: .85),
                    ],
                  ),
                ),
                child: IconButton(
                  tooltip: context.lang.setupScrollPrevious,
                  onPressed: () => move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
              ),
            ),
          if (after)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.surfaceContainerLowest.withValues(alpha: .85),
                      colors.surfaceContainerLowest,
                    ],
                  ),
                ),
                child: IconButton(
                  tooltip: context.lang.setupScrollNext,
                  onPressed: () => move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
