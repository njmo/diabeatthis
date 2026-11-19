import 'dart:convert';
import 'dart:math';

enum ChatRetention {
  day(1),
  week(7),
  month(30),
  unlimited(null);

  const ChatRetention(this.days);
  final int? days;
}

/// Non-sensitive configuration only; message content belongs in Drift.
class FamilyChatPreferences {
  const FamilyChatPreferences({
    this.enabled = true,
    this.retention = ChatRetention.week,
    this.accountExplicit = false,
    this.retentionExplicit = false,
    this.changeId,
    this.setupCommitted = true,
  });
  final bool enabled;
  final ChatRetention retention;
  final bool accountExplicit, retentionExplicit;
  final String? changeId;
  final bool setupCommitted;

  FamilyChatPreferences asDraft() =>
      FamilyChatPreferences(enabled: enabled, retention: retention);
  FamilyChatPreferences asPendingSetup() => FamilyChatPreferences(
    enabled: enabled,
    retention: retention,
    accountExplicit: accountExplicit,
    retentionExplicit: retentionExplicit,
    changeId: base64Url.encode(
      List.generate(18, (_) => Random.secure().nextInt(256)),
    ),
    setupCommitted: false,
  );

  FamilyChatPreferences committedSetup() => FamilyChatPreferences(
    enabled: enabled,
    retention: retention,
    accountExplicit: accountExplicit,
    retentionExplicit: retentionExplicit,
    changeId: changeId,
  );

  FamilyChatPreferences copyWith({bool? enabled, ChatRetention? retention}) =>
      FamilyChatPreferences(
        enabled: enabled ?? this.enabled,
        retention: retention ?? this.retention,
        accountExplicit: enabled != null || accountExplicit,
        retentionExplicit: retention != null || retentionExplicit,
        setupCommitted: setupCommitted,
        changeId: enabled == null && retention == null
            ? changeId
            : base64Url.encode(
                List.generate(18, (_) => Random.secure().nextInt(256)),
              ),
      );

  String encode() => jsonEncode({
    'enabled': enabled,
    'retention': retention.name,
    'accountExplicit': accountExplicit,
    'retentionExplicit': retentionExplicit,
    'setupCommitted': setupCommitted,
    if (changeId != null) 'changeId': changeId,
  });
  static FamilyChatPreferences decode(String? value) {
    if (value == null) return const FamilyChatPreferences();
    try {
      final data = jsonDecode(value);
      if (data is! Map<String, dynamic> || data['enabled'] is! bool) {
        return const FamilyChatPreferences(enabled: false);
      }
      final retention = ChatRetention.values
          .where((v) => v.name == data['retention'])
          .firstOrNull;
      return FamilyChatPreferences(
        enabled: data['enabled'] as bool,
        retention: retention ?? ChatRetention.week,
        accountExplicit: data['accountExplicit'] is bool
            ? data['accountExplicit'] as bool
            : data['enabled'] == false,
        retentionExplicit: data['retentionExplicit'] == true,
        changeId:
            data['changeId'] is String &&
                (data['changeId'] as String).length <= 128
            ? data['changeId'] as String
            : null,
        setupCommitted: data['setupCommitted'] != false,
      );
    } catch (_) {
      return const FamilyChatPreferences(enabled: false);
    }
  }
}

enum ChatMessageKind { text, question, answer, lowTreatment }

enum ChatDelivery { pending, sent, delivered, read, failed }
