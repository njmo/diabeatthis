import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../common/history/history_event_presentation.dart';
import '../../../common/history/history_event_type.dart';
import '../../../common/l10n/language.dart';
import 'glucose.dart';
import 'treatment_base.dart';

/// A spot glucose measurement; it does not participate in the CGM time series.
class BgCheck extends Treatment {
  BgCheck(this.reading, {this.isValid = true}) : super(createdAt: reading.date);

  final Glucose reading;
  @override
  final bool isValid;

  @override
  String getParts() => [
    '${NumberFormat('0.#', lang.localeName).format(reading.sgv)} mg/dl',
    switch (reading.type) {
      GlucoseType.finger => lang.historyGlucoseMeter,
      GlucoseType.sensor => lang.historyGlucoseSensor,
      GlucoseType.manual => lang.historyGlucoseManual,
      _ => '',
    },
    if (reading.notes?.isNotEmpty == true) reading.notes!,
  ].where((part) => part.isNotEmpty).join(' · ');

  @override
  IconData getIcon() => historyEventIcon(HistoryEventType.bgCheck);
  @override
  Color getColor() => historyEventColor(HistoryEventType.bgCheck);
}
