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
  });
  final Object recordKey;
  final Widget? fallback;
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
    final future = useMemoized(
      () => connection == null
          ? null
          : load(
              ref,
              NightscoutHistoryRepositories(connection),
            ).timeout(const Duration(seconds: 30)),
      [connection, recordKey, attempt.value],
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
      return fallback == null
          ? status
          : Column(
              children: [
                status,
                Expanded(child: fallback!),
              ],
            );
    }
    if (snapshot.connectionState != ConnectionState.done) {
      const status = Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
      return fallback == null
          ? status
          : Column(
              children: [
                status,
                Expanded(child: fallback!),
              ],
            );
    }
    final data = snapshot.data;
    return data == null
        ? Text(context.lang.activityMissingData)
        : builder(data);
  }
}
