import 'dart:ui';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_carbs_request_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/notification_event_factory.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => LanguageStrings.setSelectedLocale(const Locale('pl')));

  test('notification serialization preserves request identity and amount', () {
    const event = AapsCarbsRequestNotificationEvent(
      episodeId: 'episode-1',
      carbs: 12.5,
    );
    final decoded =
        const NotificationEventFactory().fromPayload(
              NotificationEventType.aapsCarbsRequest,
              event.toJson(),
            )
            as AapsCarbsRequestNotificationEvent;
    expect(decoded.toJson(), {'episodeId': 'episode-1', 'carbs': 12.5});
    expect(decoded.key.type, NotificationEventType.aapsCarbsRequest);
    expect(decoded.toPayload()['action_data'], {'episodeId': 'episode-1'});
  });

  test('positive fractional requests are not displayed as zero', () {
    LanguageStrings.setSelectedLocale(const Locale('en'));
    const event = AapsCarbsRequestNotificationEvent(
      episodeId: 'fraction',
      carbs: 0.04,
    );
    expect(event.title, contains('0.04'));
  });

  test('both supported languages identify AAPS as the request source', () {
    const event = AapsCarbsRequestNotificationEvent(
      episodeId: 'locale',
      carbs: 12,
    );
    LanguageStrings.setSelectedLocale(const Locale('pl'));
    expect(event.title, 'AAPS prosi o 12 g węglowodanów');
    expect(event.body, contains('dosłodzenie'));
    LanguageStrings.setSelectedLocale(const Locale('en'));
    expect(event.title, 'AAPS asks for 12 g of carbohydrates');
    expect(event.body, contains('low treatment'));
  });
}
