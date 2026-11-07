import 'dart:async';
import 'dart:ui';

import 'package:diabeatthis/common/l10n/language.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // The regression suite uses Polish labels, independently of the host locale.
  LanguageStrings.setSelectedLocale(const Locale('pl'));
  await testMain();
}
