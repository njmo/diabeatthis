import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/data/provider/shared_prefs_provider.dart';

part 'application_theme_mode_controller.g.dart';

const applicationThemeModeKey = 'application-theme-mode';

@Riverpod(keepAlive: true)
class ApplicationThemeModeController extends _$ApplicationThemeModeController {
  @override
  Future<ThemeMode> build() async {
    final prefs = await ref.watch(sharedPrefsProvider.future);
    final stored = prefs.getString(applicationThemeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    final saved = await prefs.setString(applicationThemeModeKey, mode.name);
    if (!saved) throw StateError('Could not save application theme mode.');
    state = AsyncData(mode);
  }
}
