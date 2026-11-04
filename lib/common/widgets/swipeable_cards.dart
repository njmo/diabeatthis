import 'package:flutter/material.dart';

import 'detail_tabs.dart';
import 'detail_tabs_header.dart';
import 'swipeable_card_page.dart';

/// Named, swipeable pages with independent vertical scrolling.
class SwipeableCards extends StatelessWidget {
  final bool showPageControls;
  final Widget? header;
  final TabController controller;
  final List<String> labels;
  final List<Widget> children;

  const SwipeableCards({
    super.key,
    this.header,
    this.showPageControls = true,
    required this.controller,
    required this.labels,
    required this.children,
  }) : assert(labels.length == children.length);

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              if (header != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: header,
                  ),
                ),
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
                sliver: SliverPersistentHeader(
                  pinned: true,
                  delegate: DetailTabsHeader(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: DetailTabs(
                      controller: controller,
                      labels: labels,
                      scrollable: labels.length > 3,
                    ),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: controller,
              children: [
                for (var i = 0; i < children.length; i++)
                  SwipeableCardPage(
                    key: ValueKey(labels[i]),
                    storageKey: labels[i],
                    child: children[i],
                  ),
              ],
            ),
          ),
        ),
        if (showPageControls)
          SafeArea(
            top: false,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: material.previousPageTooltip,
                    onPressed: controller.index == 0
                        ? null
                        : () => controller.animateTo(controller.index - 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Semantics(
                    label: material.tabLabel(
                      tabIndex: controller.index + 1,
                      tabCount: children.length,
                    ),
                    child: Text(
                      '${controller.index + 1} / ${children.length}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: material.nextPageTooltip,
                    onPressed: controller.index == children.length - 1
                        ? null
                        : () => controller.animateTo(controller.index + 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
