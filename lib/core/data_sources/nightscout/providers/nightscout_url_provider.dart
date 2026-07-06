import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/provider/shared_prefs_provider.dart';
import '../nightscout_storage_keys.dart';

part 'nightscout_url_provider.g.dart';

@Riverpod(keepAlive: true)
Future<String> nightscoutUrl(Ref ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return prefs.getString(nightscoutUrlKey) ?? '';
}

@Riverpod(keepAlive: true)
Future<String> nightscoutToken(Ref ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return prefs.getString(nightscoutTokenKey) ?? '';
}
