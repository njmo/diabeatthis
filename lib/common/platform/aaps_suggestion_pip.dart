import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../features/meal_advisor/domain/utils/extended_carbs_schedule_formatter.dart';
import '../l10n/language.dart';
import 'external_app_installation_checker.dart';

final aapsSuggestionPipProvider = Provider<AapsSuggestionPip>((ref) {
  return AapsSuggestionPip(enabled: !kIsWeb && Platform.isAndroid);
});

final aapsSuggestionOverlayProvider = Provider<AapsSuggestionPip>((ref) {
  return AapsSuggestionPip(
    // AAPS hides application overlays; use system PiP in the normal flow.
    enabled: false,
    channelName: 'pl.diabeatthis.app/suggestion_overlay',
  );
});

class AapsSuggestionPip {
  const AapsSuggestionPip({
    this.enabled = true,
    this.channelName = 'pl.diabeatthis.app/suggestion_pip',
  });

  final bool enabled;
  final String channelName;

  bool get isSupported =>
      enabled && defaultTargetPlatform == TargetPlatform.android;

  Future<void> dismiss(String sessionId) async {
    try {
      await MethodChannel(
        channelName,
      ).invokeMethod<void>('dismiss', {'sessionId': sessionId});
    } on MissingPluginException {
      // No native card exists on unsupported platforms.
    } on PlatformException {
      // Manual dismissal remains available if Android already removed the activity.
    }
  }

  /// Reuses the same localized content for the overlay and fallback PiP.
  Future<bool> open({
    required AapsBolusSuggestionNotificationEvent event,
    required AppLocalizations strings,
    String? sessionId,
  }) async {
    if (!isSupported) {
      return false;
    }
    final delay = event.extendedCarbsDelayMinutes;
    final duration = event.extendedCarbsDurationMinutes;
    final schedule =
        event.extendedCarbs > 0 && delay != null && duration != null
        ? strings.aapsPipSchedule(
            formatExtendedCarbsScheduleMinutes(delay),
            formatExtendedCarbsScheduleMinutes(duration),
          )
        : strings.aapsPipNoSchedule;
    final hasExtendedCarbs = event.extendedCarbs > 0;
    try {
      return await MethodChannel(channelName).invokeMethod<bool>('openAaps', {
            'packageName': ExternalDataApp.aaps.androidPackageName,
            'sessionId': sessionId,
            'title': event.mealName?.trim().isNotEmpty == true
                ? event.mealName!.trim()
                : strings.aapsSuggestionTitle,
            'closeLabel': strings.aapsSuggestionClose,
            'labels': [
              strings.aapsPipCarbs,
              if (hasExtendedCarbs)
                event.extendedCarbsAreAdditional
                    ? strings.aapsPipAdditionalExtendedCarbs
                    : strings.aapsPipExtendedCarbs,
              if (hasExtendedCarbs && delay != null && duration != null)
                strings.aapsPipTime,
            ],
            'values': [
              '${event.carbs} g',
              if (hasExtendedCarbs) '${event.extendedCarbs} g',
              if (hasExtendedCarbs && delay != null && duration != null)
                schedule,
            ],
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
