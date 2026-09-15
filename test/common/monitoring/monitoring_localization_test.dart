import 'dart:ui';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/monitoring/activity_monitoring_phase.dart';
import 'package:diabeatthis/common/monitoring/activity_monitoring_status.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_phase.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_status.dart';
import 'package:diabeatthis/common/monitoring/monitoring_status.dart';
import 'package:diabeatthis/common/monitoring/monitoring_status_formatter.dart';
import 'package:diabeatthis/core/notifications/definitions/notification_channel_catalog_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'channel names follow language while channel identifiers remain stable',
    () {
      addTearDown(() => LanguageStrings.setSelectedLocale(const Locale('pl')));
      final catalog = NotificationChannelDefinitionCatalogImpl();
      LanguageStrings.setSelectedLocale(const Locale('en'));
      final english = catalog.all;
      LanguageStrings.setSelectedLocale(const Locale('pl'));
      final polish = catalog.all;
      expect(
        polish.map((channel) => channel.id),
        english.map((channel) => channel.id),
      );
      expect(english.first.name, 'Meal Wait Notifications');
      expect(polish.first.name, 'Powiadomienia o posiłkach');
      expect(
        polish.map((channel) => channel.name),
        isNot(english.map((channel) => channel.name)),
      );
    },
  );

  test(
    'foreground monitoring follows the selected language and preserves event names',
    () {
      addTearDown(() => LanguageStrings.setSelectedLocale(const Locale('pl')));
      final status = MonitoringStatus(
        meal: const MealMonitoringStatus(phase: MealMonitoringPhase.idle),
        activity: ActivityMonitoringStatus(
          phase: ActivityMonitoringPhase.active,
          name: 'Bieganie',
          startsAt: DateTime(2026, 9, 15, 14, 30),
        ),
      );
      const formatter = MonitoringStatusFormatter();
      LanguageStrings.setSelectedLocale(const Locale('en'));
      expect(formatter.format(status).title, 'Activity monitoring');
      expect(formatter.format(status).text, 'Bieganie · since 14:30');
      LanguageStrings.setSelectedLocale(const Locale('pl'));
      expect(formatter.format(status).title, 'Monitorowanie aktywności');
      expect(formatter.format(status).text, 'Bieganie · od 14:30');
    },
  );
}
