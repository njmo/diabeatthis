import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nightscout_cloud_connection_tester.dart';

typedef NightscoutConnectionCheck =
    Future<void> Function({required String url, required String token});

/// Boundary shared by initial setup and later connection settings changes.
final nightscoutConnectionCheckProvider = Provider<NightscoutConnectionCheck>(
  (ref) =>
      ({required String url, required String token}) =>
          NightscoutCloudConnectionTester.fromUrl(
            url,
            nightscoutToken: token,
          ).testConnection(),
);
