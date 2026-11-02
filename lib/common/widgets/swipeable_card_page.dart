import 'package:flutter/material.dart';

/// Keeps scroll offsets separate from the disclosure state inside a card.
class SwipeableCardPage extends StatefulWidget {
  const SwipeableCardPage({
    super.key,
    required this.storageKey,
    required this.child,
  });
  final String storageKey;
  final Widget child;

  @override
  State<SwipeableCardPage> createState() => SwipeableCardPageState();
}

class SwipeableCardPageState extends State<SwipeableCardPage> {
  final contentStorage = PageStorageBucket();

  @override
  Widget build(BuildContext context) => CustomScrollView(
    key: PageStorageKey(widget.storageKey),
    slivers: [
      SliverOverlapInjector(
        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        sliver: SliverToBoxAdapter(
          child: PageStorage(bucket: contentStorage, child: widget.child),
        ),
      ),
    ],
  );
}
