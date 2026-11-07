import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../l10n/language.dart';
import '../models/collection_state.dart';

class CollectionListView<T> extends StatelessWidget {
  const CollectionListView({
    super.key,
    required this.state,
    required this.emptyLabel,
    required this.onRetry,
    required this.onLoadMore,
    required this.itemBuilder,
    this.header = const [],
  });
  final CollectionState<T> state;
  final List<Widget> header;
  final String emptyLabel;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final Widget Function(BuildContext, T) itemBuilder;
  @override
  Widget build(BuildContext context) {
    if (header.isEmpty && state.items.isEmpty && state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (header.isEmpty && state.items.isEmpty && state.failed) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.lang.commonRetry),
        ),
      );
    }
    if (header.isEmpty && state.items.isEmpty) {
      return Center(child: Text(emptyLabel));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if ((notification is ScrollUpdateNotification ||
                notification is OverscrollNotification) &&
            notification.metrics.extentAfter < 120) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          112 + MediaQuery.paddingOf(context).bottom,
        ),
        scrollCacheExtent: const ScrollCacheExtent.pixels(0),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: header.length + state.items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index < header.length) return header[index];
          index -= header.length;
          if (index < state.items.length) {
            return itemBuilder(context, state.items[index]);
          }
          if (state.loadingMore) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.failed) {
            return TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.lang.commonRetry),
            );
          }
          return SizedBox(height: state.hasMore ? 24 : 8);
        },
      ),
    );
  }
}
