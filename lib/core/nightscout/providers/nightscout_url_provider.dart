import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/provider/shared_prefs_provider.dart';

part 'nightscout_url_provider.g.dart';

const _nightscoutUrlKey = 'nightscout_url';

@riverpod
Future<String?> nightscoutUrl(Ref ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return prefs.getString(_nightscoutUrlKey);
}