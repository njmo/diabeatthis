import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import '../../history/nightscout_history_repositories.dart';
import '../../l10n/language.dart';

/// Fetches only while a record is visible, bound to its family/record revision
/// and to the currently configured Nightscout connection. No local DB writes.
class NightscoutRecordHistory<T> extends HookConsumerWidget {
  const NightscoutRecordHistory({
    super.key,
    required this.recordKey,
    required this.load,
    required this.builder,
    this.fallback,
    this.errorFallback,
    this.expandFallback = true,
    this.refreshKey,
    this.keepPreviousDuringRefresh = false,
    this.showFallbackOnEmpty = false,
  });
  final Object recordKey;
  final Object? refreshKey;
  final bool keepPreviousDuringRefresh;
  final bool showFallbackOnEmpty;
  final Widget? fallback;
  final Widget? errorFallback;
  final bool expandFallback;
  final Future<T?> Function(
    WidgetRef ref,
    NightscoutHistoryRepositories history,
  )
  load;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(nightscoutRepositoryProvider);
    final attempt = useState(0);
    final connection = repository.isLoading ? null : repository.asData?.value;
    // Cache belongs to one exact connection and record scope, never another family.
    final retained = useMemoized(() => <T>[], [connection, recordKey]);
    final future = useMemoized(
      () => connection == null
          ? null
          : load(
              ref,
              NightscoutHistoryRepositories(connection),
            ).timeout(const Duration(seconds: 30)),
      [connection, recordKey, refreshKey, attempt.value],
    );
    final snapshot = useFuture(future, preserveState: false);
    if (repository.hasError || snapshot.hasError) {
      final status = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.lang.nightscoutHistoryUnavailable),
          IconButton(
            tooltip: context.lang.commonRetry,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              if (repository.hasError) {
                ref.invalidate(nightscoutRepositoryProvider);
              }
              attempt.value++;
            },
          ),
        ],
      );
      final content = errorFallback ?? fallback;
      return content == null
          ? status
          : Column(
              mainAxisSize: expandFallback
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                status,
                if (expandFallback) Expanded(child: content) else content,
              ],
            );
    }
    if (snapshot.connectionState != ConnectionState.done) {
      if (keepPreviousDuringRefresh && retained.isNotEmpty) {
        return builder(retained.single);
      }
      const status = Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
      return fallback == null
          ? status
          : Column(
              mainAxisSize: expandFallback
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                status,
                if (expandFallback) Expanded(child: fallback!) else fallback!,
              ],
            );
    }
    final data = snapshot.data;
    if (data != null) {
      retained
        ..clear()
        ..add(data);
    }
    if (data != null) return builder(data);
    final missing = Text(context.lang.activityMissingData);
    if (!showFallbackOnEmpty || fallback == null) return missing;
    return Column(
      mainAxisSize: expandFallback ? MainAxisSize.max : MainAxisSize.min,
      children: [
        missing,
        if (expandFallback) Expanded(child: fallback!) else fallback!,
      ],
    );
  }
}
