import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/platform/network_connection_provider.dart';
import '../config/data_source_config.dart';
import '../config/data_source_config_provider.dart';

final effectiveHistorySourceProvider = FutureProvider<HistorySource>((
  ref,
) async {
  final config = await ref.watch(dataSourceConfigProvider.future);
  if (config.historySource != HistorySource.localOnMobile) {
    return config.historySource;
  }

  final connections = await ref.watch(networkConnectionProvider.future);
  final usesMobile =
      connections.contains(ConnectivityResult.mobile) &&
      !connections.contains(ConnectivityResult.wifi) &&
      !connections.contains(ConnectivityResult.ethernet);
  return usesMobile ? HistorySource.local : HistorySource.cloud;
});
