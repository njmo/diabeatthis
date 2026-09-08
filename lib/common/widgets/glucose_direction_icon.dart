import 'package:flutter/material.dart';

IconData iconForDirection(String? dir) {
  switch (dir) {
    case 'DoubleUp':
      return Icons.keyboard_double_arrow_up_rounded;
    case 'SingleUp':
      return Icons.arrow_upward_rounded;
    case 'FortyFiveUp':
      return Icons.north_east_rounded;
    case 'Flat':
      return Icons.arrow_forward_rounded;
    case 'FortyFiveDown':
      return Icons.south_east_rounded;
    case 'SingleDown':
      return Icons.arrow_downward_rounded;
    case 'DoubleDown':
      return Icons.keyboard_double_arrow_down_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}
