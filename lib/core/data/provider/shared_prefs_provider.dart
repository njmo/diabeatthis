import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'shared_prefs_provider.g.dart';

@riverpod
Future<SharedPreferences> sharedPrefs(Ref ref) async {
  return SharedPreferences.getInstance();
}
