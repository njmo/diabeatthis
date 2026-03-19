import 'package:freezed_annotation/freezed_annotation.dart';

import 'notification_action_input_def.dart';
import 'notification_action_type.dart';

part 'notification_action_def.freezed.dart';

@freezed
sealed class NotificationActionDef with _$NotificationActionDef{
  const NotificationActionDef._();

  const factory NotificationActionDef.plain({
    required NotificationActionType type,
    required String label,
    @Default(true) bool openApp,
  }) = PlainNotificationActionDef;

  const factory NotificationActionDef.text({
    required NotificationActionType type,
    required String label,
    @Default(true) bool openApp,
    required NotificationActionInputDef inputActionDef,
  }) = TextNotificationActionDef;
}