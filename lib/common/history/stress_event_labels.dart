import '../../core/domain/model/stress_level.dart';
import '../l10n/language.dart';

String stressLevelLabel(AppLocalizations messages, StressLevel level) =>
    switch (level) {
      StressLevel.low => messages.manualEventStressLow,
      StressLevel.moderate => messages.manualEventStressModerate,
      StressLevel.high => messages.manualEventStressHigh,
    };
