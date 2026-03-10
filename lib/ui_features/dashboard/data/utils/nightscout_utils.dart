import 'package:flutter/material.dart';

Color getColorForValue(int value) {
  if (value >= 0 && value < 70) {
    return Colors.red;
  } else if (value >= 70 && value < 180) {
    return Colors.green;
  } else if (value >= 180 && value < 250) {
    return Colors.orangeAccent;
  } else if (value >= 250 && value <= 400) {
    return Colors.red;
  } else {
    return Colors.grey;
  }
}

int parseTick(String? tickRaw) {
  if (tickRaw == null) return 0;
  final cleaned = tickRaw.trim().replaceAll(',', '.');
  return int.tryParse(cleaned) ??
      int.tryParse(cleaned.replaceAll('+', '')) ??
      0;
}

String directionForTick(int tick) {
  if (tick >= 20) return 'DoubleUp';
  if (tick >= 10) return 'SingleUp';
  if (tick >= 5) return 'FortyFiveUp';
  if (tick <= -20) return 'DoubleDown';
  if (tick <= -10) return 'SingleDown';
  if (tick <= -5) return 'FortyFiveDown';
  return 'Flat';
}

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

String formatAgo(Duration d) {
  if(d.isNegative) return 'teraz';
  if (d.inMinutes < 1) return '${d.inSeconds}s temu';
  if (d.inHours < 1) return '${d.inMinutes} min temu';
  if (d.inHours < 24) return '${d.inHours} h temu';
  return '${d.inDays} d temu';
}