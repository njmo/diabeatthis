import '../data/family_chat_database.dart';
import '../data/family_chat_notification_platform.dart';
import '../data/family_chat_settings_store.dart';
import 'family_chat_settings_controller.dart';

/// The only bridge from settings state to local capabilities. Never derives an
/// accepted ON token from a token read after server verification.
class FamilyChatSettingsLocalGate {
  const FamilyChatSettingsLocalGate({
    required this.uid,
    required this.db,
    required this.store,
    required this.currentUid,
    required this.controller,
    required this.cancelClinical,
    this.cancelNotification,
  });
  final String uid;
  final FamilyChatDatabase db;
  final FamilyChatSettingsStore store;
  final String? Function() currentUid;
  final FamilyChatSettingsController Function() controller;
  final Future<void> Function(String uid) cancelClinical;
  final Future<void> Function(FamilyChatNotice)? cancelNotification;
  bool get _current => currentUid() == uid;

  Future<String?> closeAdmission(bool revoke) async {
    if (!_current) throw StateError('Account changed');
    if (revoke) return db.fence.revokeAccount(uid);
    final expected = await db.fence.read();
    final token = await db.fence.accountRevocation(uid);
    if (!_current) throw StateError('Account changed');
    if (expected['uid'] != null && expected['uid'] != uid) return token;
    if (await db.fence.block(expected: expected) == null) {
      throw StateError('Admission changed');
    }
    return token;
  }

  Future<void> _purge() async {
    // The independent fence is already closed, so a clinical writer either
    // rolls back its old guard check or commits before this cancellation.
    await cancelClinical(uid);
    await db.clearAccount(uid, preserveHistory: true);
    final notices = await db.noticesForAccount(uid);
    await FamilyChatNotificationPlatform.cancel(
      db,
      notices,
      keepTrying: () => false,
      operation: cancelNotification,
    );
    // Unit/non-Android clients may use an injected cancellation operation.
    if (cancelNotification != null) {
      for (final notice in await db.noticesForAccount(uid)) {
        await cancelNotification!(notice);
        await db.confirmCancelled(notice);
      }
    }
    if ((await db.noticesForAccount(uid)).isNotEmpty) {
      throw StateError('Notification cancellation is pending');
    }
  }

  Future<void> apply(FamilyChatSettingsAdmission admission) async {
    if (!_current) throw StateError('Account changed');
    final settings = controller();
    final snapshot = settings.state;
    if (admission == FamilyChatSettingsAdmission.held) {
      await closeAdmission(false);
      return;
    }
    if (admission == FamilyChatSettingsAdmission.revoked) {
      if (settings.denied) {
        // Membership denial is not a new account-wide OFF preference.
        await closeAdmission(false);
        await _purge();
        return;
      }
      final revocation = await db.fence.ensureAccountRevocation(uid);
      await _purge();
      if (snapshot['policy']?['legacyOff'] == true &&
          (revocation.created ||
              snapshot['policy']?['localToken'] == revocation.token)) {
        await store.update(uid, (state) {
          if (state['_revision'] != snapshot['_revision'] ||
              state['policy']?['id'] != snapshot['policy']?['id']) {
            return;
          }
          state['policy']['localToken'] = revocation.token;
        });
      }
      final config = snapshot['confirmed'];
      if (revocation.created &&
          settings.fresh &&
          config != null &&
          (config['account']['enabled'] == false ||
              config['policy']['enabled'] == false)) {
        await store.update(uid, (state) {
          // Never replace a newer command/ack while local cleanup was waiting.
          if (state['_revision'] != snapshot['_revision']) return;
          state['offAck'] = {
            'token': revocation.token,
            'familyId': config['familyId'],
            'epoch': config['epoch'],
            'accountRevision': config['account']['enabled'] == false
                ? config['account']['revision']
                : null,
            'policyRevision': config['policy']['enabled'] == false
                ? config['policy']['revision']
                : null,
          };
        });
      }
      return;
    }
    // The accepted token comes from the durable gesture/ack, captured before
    // any awaits here. The current token is read only for equality/failure.
    final accepted = snapshot['opening']?['token'];
    final current = await db.fence.accountRevocation(uid);
    if (current != null) {
      if (accepted is! String || accepted != current) {
        throw StateError('A newer or untracked OFF exists');
      }
      await _purge();
      if (!_current || !settings.localAllowed) {
        throw StateError('Admission changed');
      }
      if (!await db.fence.clearAccountRevocation(uid, accepted)) {
        throw StateError('A newer OFF exists');
      }
    }
    if (!_current || !settings.localAllowed) {
      throw StateError('Admission changed');
    }
    // RuntimeSession captures its guard version before its own fresh getConfig
    // and checks activation success. A later OFF latch blocks it atomically.
  }
}
