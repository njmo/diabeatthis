import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/data/provider/shared_prefs_provider.dart';
import 'application_theme.dart';

part 'application_theme_controller.g.dart';

const applicationThemeKey = 'application-theme';

@Riverpod(keepAlive: true)
class ApplicationThemeController extends _$ApplicationThemeController {
  @override
  Future<ApplicationTheme> build() async {
    final prefs = await ref.watch(sharedPrefsProvider.future);
    return ApplicationTheme.fromName(prefs.getString(applicationThemeKey));
  }

  Future<void> setTheme(ApplicationTheme theme) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final saved = await prefs.setString(applicationThemeKey, theme.name);
    if (!saved) throw StateError('Could not save application theme.');
    state = AsyncData(theme);
  }
}
