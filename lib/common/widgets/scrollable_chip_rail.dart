import 'package:flutter/material.dart';

import '../l10n/language.dart';

/// A single row with separate overflow controls that never cover chip labels.
class ScrollableChipRail extends StatefulWidget {
  const ScrollableChipRail({super.key, required this.children});
  final List<Widget> children;

  @override
  State<ScrollableChipRail> createState() => ScrollableChipRailState();
}

class ScrollableChipRailState extends State<ScrollableChipRail> {
  final controller = ScrollController();
  final contentKey = GlobalKey();
  final itemKeys = <GlobalKey>[];
  bool before = false;
  bool after = false;
  int remaining = 0;

  void refresh() {
    if (!mounted || !controller.hasClients) return;
    final nextBefore = controller.position.extentBefore > 1;
    final nextAfter = controller.position.extentAfter > 1;
    final content = contentKey.currentContext?.findRenderObject() as RenderBox?;
    var nextRemaining = 0;
    if (nextAfter && content != null) {
      final end = controller.offset + controller.position.viewportDimension;
      for (final key in itemKeys) {
        final box = key.currentContext?.findRenderObject() as RenderBox?;
        if (box != null &&
            box.localToGlobal(Offset.zero, ancestor: content).dx +
                    box.size.width >
                end + 1) {
          nextRemaining++;
        }
      }
    }
    if (before == nextBefore &&
        after == nextAfter &&
        remaining == nextRemaining) {
      return;
    }
    setState(() {
      before = nextBefore;
      after = nextAfter;
      remaining = nextRemaining;
    });
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(refresh);
  }

  @override
  void didUpdateWidget(ScrollableChipRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
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
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpTo(target);
    } else {
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    while (itemKeys.length < widget.children.length) {
      itemKeys.add(GlobalKey());
    }
    if (itemKeys.length > widget.children.length) {
      itemKeys.removeRange(widget.children.length, itemKeys.length);
    }
    return SizedBox(
      height: (MediaQuery.textScalerOf(context).scale(18) + 24).clamp(
        44.0,
        double.infinity,
      ),
      child: Row(
        children: [
          if (before)
            IconButton(
              tooltip: context.lang.setupScrollPrevious,
              onPressed: () => move(-1),
              icon: const Icon(Icons.chevron_left),
            ),
          Expanded(
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
                return false;
              },
              child: SingleChildScrollView(
                controller: controller,
                scrollDirection: Axis.horizontal,
                child: Row(
                  key: contentKey,
                  children: [
                    for (
                      var index = 0;
                      index < widget.children.length;
                      index++
                    ) ...[
                      if (index > 0) const SizedBox(width: 6),
                      Center(
                        key: itemKeys[index],
                        child: widget.children[index],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (after)
            SizedBox(
              width: 76,
              child: Tooltip(
                message: context.lang.setupScrollNext,
                child: TextButton(
                  onPressed: () => move(1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text('+$remaining', maxLines: 1)),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
