import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notifications_channel_definition.dart';

NotificationChannelDefinition get targetNotificationChannelDefinition =>
    NotificationChannelDefinition(
      type: NotificationChannelType.target,
      id: 'temp_target_channel_v2',
      name: lang.notificationChannelTempTargetName,
      description: lang.notificationChannelTempTargetDescription,
      importance: Importance.max,
    );
