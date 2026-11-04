import 'package:flutter/material.dart';

abstract final class ApplicationAccentColors {
  static Color warm(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFFFFBD69)
      : const Color(0xFFAE580B);

  static Color glow(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFFB86A22)
      : const Color(0xFFFFD89B);
}
