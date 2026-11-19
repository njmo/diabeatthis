import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../backend/authenticated_callable_transport.dart';
import '../data/family_chat_remote.dart';
import '../data/family_chat_settings_store.dart';
import '../domain/family_chat_preferences.dart';
import '../domain/family_treatment_authorization.dart';

enum FamilyChatSettingsAdmission { held, revoked, open }

/// Settings transport outlives the stopped conversation session. Local OFF is
/// durable before network access; ON requires a fresh authoritative response.
class FamilyChatSettingsController extends ChangeNotifier {
  FamilyChatSettingsController({
    required this.uid,
    required this.api,
    required this.store,
    required this.currentUid,
    required this.applyLocal,
    required this.closeAdmission,
    required this.readRevocation,
  });
  final String uid;
  final FamilyChatApi api;
  final FamilyChatSettingsStore store;
  final String? Function() currentUid;

  /// Independent of the chat/settings writer: closes the cross-isolate fence.
  final Future<String?> Function(bool revoke) closeAdmission;
  final Future<String?> Function() readRevocation;

  /// Held preserves the cache/clinical intents; revoked purges chat and cancels
  /// unapplied intentions. Opening still uses the runtime's purge barriers.
  final Future<void> Function(FamilyChatSettingsAdmission admission) applyLocal;
  Map<String, dynamic> _state = {};
  bool _disposed = false, _fresh = false, _again = false;
  bool _applying = false, _denied = false;
  int _closingMutations = 0;
  int _revokingMutations = 0;
  final _failedClosed = <String>{}, _failedRevoked = <String>{};
  FamilyChatSettingsAdmission? _applied;
  Future<void> _mutations = Future.value(), _local = Future.value();
  Future<void>? _network;
  String? error;
  bool initialized = false;
  bool get _current => !_disposed && currentUid() == uid;
  bool get fresh => _fresh && _current;
  void requireFreshScope() {
    _fresh = false;
    _applied = null;
    _changed();
  }

  bool get denied => _denied;
  bool get synchronizing => _network != null;
  Map<String, dynamic> get state =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(_state)) as Map);
  Map<String, dynamic>? get confirmed =>
      state['confirmed'] as Map<String, dynamic>?;
  FamilyChatSettingsAdmission get admission {
    final config = _state['confirmed'];
    if (_denied ||
        _revokingMutations > 0 ||
        _failedRevoked.isNotEmpty ||
        _state['account']?['changes']?['accountEnabled'] == false ||
        _state['policy']?['legacyOff'] == true ||
        fresh &&
            (config?['account']?['enabled'] == false ||
                config?['policy']?['enabled'] == false)) {
      return FamilyChatSettingsAdmission.revoked;
    }
    return fresh &&
            _failedClosed.isEmpty &&
            _closingMutations == 0 &&
            config?['account']?['enabled'] == true &&
            config?['policy']?['enabled'] == true &&
            _state['account'] == null &&
            _state['policy']?['legacyRemoved'] != true
        ? FamilyChatSettingsAdmission.open
        : FamilyChatSettingsAdmission.held;
  }

  bool get localAllowed => admission == FamilyChatSettingsAdmission.open;
  bool get readyForRuntime =>
      !_applying &&
      localAllowed &&
      _applied == FamilyChatSettingsAdmission.open;
  bool get canRequestEnable =>
      initialized &&
      fresh &&
      !_applying &&
      (_applied == admission || admission == FamilyChatSettingsAdmission.open);
  bool get mayUseCachedRead =>
      initialized &&
      !_applying &&
      !fresh &&
      admission == FamilyChatSettingsAdmission.held &&
      _failedClosed.isEmpty &&
      _state['account'] == null &&
      _state['policy'] == null &&
      ![
        'permission-denied',
        'unauthenticated',
        'failed-precondition',
      ].contains(error);

  void _adopt(Map<String, dynamic> value) {
    if (((value['_revision'] as int?) ?? 0) >=
        ((_state['_revision'] as int?) ?? 0)) {
      _state = value;
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  String _generation() =>
      base64Url.encode(List.generate(18, (_) => Random.secure().nextInt(256)));

  Future<void> start() async {
    if (!_current) return;
    await _applyLocal();
    _adopt(await store.read(uid));
    if (!_current) return;
    if ((_state['policy']?['changes'] as Map?)?.containsKey('familyEnabled') ==
        true) {
      _adopt(
        await store.update(uid, (state) {
          final command = state['policy'] as Map?;
          if ((command?['changes'] as Map?)?.containsKey('familyEnabled') !=
              true) {
            return;
          }
          command!['legacyOff'] = command['changes']['familyEnabled'] == false;
          command['legacyRemoved'] = true;
          command['changes'] = <String, dynamic>{};
          command['conflict'] = 'scope';
        }),
      );
    }
    final token = await readRevocation();
    if (!_current) return;
    if (token != null &&
        _state['account']?['localToken'] != token &&
        _state['policy']?['localToken'] != token &&
        _state['opening']?['token'] != token &&
        _state['offAck']?['token'] != token) {
      _adopt(
        await store.update(uid, (state) {
          state['account'] = {
            'id': _generation(),
            'changes': {'accountEnabled': false},
            'expectedRevision': null,
            'localToken': token,
          };
        }),
      );
    }
    await _applyLocal();
    initialized = true;
    _changed();
    unawaited(synchronize());
  }

  Future<void> _applyLocal() {
    _local = _local.catchError((Object _) {}).then((_) async {
      if (!_current) return;
      final next = admission;
      if (_applied == next) return;
      _applied = null;
      _applying = true;
      _changed();
      try {
        await applyLocal(next);
        if (_current) _applied = next;
      } finally {
        _applying = false;
        _changed();
      }
    });
    return _local;
  }

  Future<void> setAccountEnabled(bool enabled) {
    if (!initialized) throw StateError('Local settings are still loading');
    final config = confirmed;
    if (enabled && (config == null || !canRequestEnable)) {
      throw StateError('Load account settings before enabling conversations');
    }
    return _request('account', {
      'changes': {'accountEnabled': enabled},
      'expectedRevision': config?['account']?['revision'],
    }, closes: true);
  }

  Future<void> setFamilyPolicy({required ChatRetention retention}) {
    if (!initialized) throw StateError('Local settings are still loading');
    if (_state['policy'] != null) {
      throw StateError('Finish the pending family setting first');
    }
    final config = confirmed;
    if (config == null || config['canManage'] != true) {
      throw StateError('Family settings are unavailable');
    }
    return _request('policy', {
      'familyId': config['familyId'],
      'epoch': config['epoch'],
      'expectedRevision': config['policy']['revision'],
      'changes': {'retention': retention.name},
    }, closes: false);
  }

  Future<void> initializeFounder(ChatRetention retention) {
    if (!initialized) throw StateError('Local settings are still loading');
    if (_state['policy'] != null) return Future.value();
    final config = confirmed;
    if (config == null) throw StateError('Load family settings first');
    return _request('policy', {
      'familyId': config['familyId'],
      'epoch': config['epoch'],
      'expectedRevision': 0,
      'changes': {'initializeIfAbsent': true, 'retention': retention.name},
    }, closes: false);
  }

  Future<void> retryPending(String kind) {
    final command = _state[kind] as Map?;
    if (!initialized || command == null) throw StateError('No pending setting');
    final changes = command['changes'] as Map;
    if (kind == 'account') {
      return setAccountEnabled(changes['accountEnabled'] as bool);
    }
    final config = confirmed;
    if (kind != 'policy' ||
        config == null ||
        config['canManage'] != true ||
        command['familyId'] != config['familyId'] ||
        command['epoch'] != config['epoch']) {
      throw StateError('Choose settings for the current family');
    }
    if (command['legacyRemoved'] == true) {
      throw StateError('Discard the removed family setting');
    }
    return _request('policy', {
      'familyId': config['familyId'],
      'epoch': config['epoch'],
      'expectedRevision': config['policy']['revision'],
      'changes': Map<String, dynamic>.from(changes),
    }, closes: false);
  }

  Future<void> discardPolicyConflict() async {
    _adopt(await store.read(uid));
    final command = _state['policy'] as Map?;
    if (!initialized || command?['conflict'] == null) {
      throw StateError('No conflicting family setting');
    }
    final legacyToken = command!['legacyOff'] == true
        ? command['localToken']
        : null;
    if (command['legacyOff'] == true) {
      if (legacyToken is! String) {
        throw StateError('Verify the legacy revocation first');
      }
      final config = await _fetch();
      if (config['account']['enabled'] != true ||
          config['policy']['enabled'] != true ||
          config['familyId'] != command['familyId'] ||
          config['epoch'] != command['epoch']) {
        throw StateError('The current family must allow conversations');
      }
    }
    await _updateCommand('policy', command['id'] as String, (state) {
      if (legacyToken is String) {
        state['opening'] = {'token': legacyToken, 'intentId': command['id']};
      }
      state.remove('policy');
    });
    unawaited(synchronize());
  }

  Future<void> _request(
    String kind,
    Map<String, dynamic> command, {
    required bool closes,
  }) {
    if (!_current) throw StateError('Account changed');
    final isOff = command['changes']['accountEnabled'] == false;
    if (closes) _closingMutations++;
    if (isOff) _revokingMutations++;
    _changed();
    Object? barrierFailure;
    String? localToken;
    final barrier = closes
        ? Future<String?>.sync(() => closeAdmission(isOff)).then<void>(
            (value) {
              localToken = value;
            },
            onError: (Object failure) {
              barrierFailure = failure;
            },
          )
        : Future<void>.value();
    final id = _generation();
    _mutations = _mutations.catchError((Object _) {}).then((_) async {
      var persisted = false;
      try {
        if (!_current) throw StateError('Account changed');
        await barrier;
        if (barrierFailure != null) {
          throw StateError('Local admission could not close');
        }
        final updated = await store.update(uid, (state) {
          state[kind] = {
            ...command,
            'id': id,
            if (closes) 'localToken': localToken,
          };
        });
        if (!_current) return;
        _adopt(updated);
        persisted = true;
        if (closes) {
          _failedClosed.remove(kind);
          _failedRevoked.remove(kind);
        }
        error = null;
        await _applyLocal();
      } catch (_) {
        if (closes && !persisted) _failedClosed.add(kind);
        if (isOff && !persisted) _failedRevoked.add(kind);
        if (_current) {
          error = 'local';
          try {
            await _applyLocal();
          } catch (_) {
            /* Keep admission closed. */
          }
        }
        rethrow;
      } finally {
        if (closes) _closingMutations--;
        if (isOff) _revokingMutations--;
        _changed();
      }
      unawaited(synchronize());
    });
    return _mutations;
  }

  Future<void> synchronize() {
    if (!initialized) return Future.value();
    _again = true;
    if (_network != null) return _network!;
    final operation = Future<void>.microtask(() async {
      var passes = 0;
      while (_current && _again && passes++ < 4) {
        _again = false;
        try {
          await _pass();
          if (_current) error = null;
        } catch (failure) {
          if (_current) {
            final code = failure is CallableFailure
                ? failure.rejectionCode ?? failure.code
                : null;
            if ([
              'permission-denied',
              'unauthenticated',
              'failed-precondition',
            ].contains(code)) {
              _fresh = false;
              _denied = code == 'permission-denied';
              error = code;
            } else {
              error = 'pending';
            }
          }
        }
        if (_current) {
          try {
            await _applyLocal();
          } catch (_) {
            error = 'local';
          }
          _changed();
        }
      }
    });
    _network = operation.whenComplete(() {
      _network = null;
      _changed();
    });
    return _network!;
  }

  Map<String, dynamic> _validated(Map<String, dynamic> value) {
    bool revision(Object? v) => v is int && v >= 0 && v <= 9007199254740991;
    bool id(Object? v) =>
        v is String && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(v);
    if (value['uid'] != uid ||
        !id(value['familyId']) ||
        !id(value['epoch']) ||
        value['account']?['enabled'] is! bool ||
        value['policy']?['enabled'] is! bool ||
        !revision(value['historyGeneration'] ?? 0) ||
        !revision(value['account']?['revision']) ||
        !revision(value['policy']?['revision']) ||
        value['canManage'] is! bool ||
        value['policyConfigured'] is! bool ||
        !ChatRetention.values.any(
          (v) => v.name == value['policy']?['retention'],
        ) ||
        familyTreatmentAuthorizationFromConfig(value) == null) {
      throw StateError('Invalid family settings');
    }
    return {
      'uid': uid,
      'familyId': value['familyId'],
      'epoch': value['epoch'],
      'historyGeneration': value['historyGeneration'] ?? 0,
      'canManage': value['canManage'],
      'canInitialize':
          value['canManage'] == true &&
          (value['members'] as List? ?? []).any(
            (member) => member['uid'] == uid && member['role'] == 'child',
          ),
      'policyConfigured': value['policyConfigured'],
      'account': {
        for (final key in ['enabled', 'revision', 'offGeneration'])
          key: value['account'][key],
      },
      'policy': {
        for (final key in ['enabled', 'revision', 'offGeneration', 'retention'])
          key: value['policy'][key],
      },
    };
  }

  Future<Map<String, dynamic>> _fetch() async {
    final value = _validated(await api.call('getFamilyChatConfig', {}));
    if (!_current) throw StateError('Account changed');
    final updated = await store.update(uid, (state) async {
      if (!_current) throw StateError('Account changed');
      final previous = state['confirmed'];
      if (previous != null &&
          previous['account']['revision'] > value['account']['revision']) {
        throw StateError('Stale account settings');
      }
      if (previous?['familyId'] == value['familyId'] &&
          previous?['epoch'] == value['epoch'] &&
          (previous['policy']['revision'] > value['policy']['revision'] ||
              (previous['historyGeneration'] as int? ?? 0) >
                  value['historyGeneration'])) {
        throw StateError('Stale family settings');
      }
      final scope = jsonEncode([uid, value['familyId'], value['epoch']]);
      final generation = value['historyGeneration'] as int;
      final history = await store.db.observeHistoryGeneration(
        scope,
        generation,
      );
      if (!_current) throw StateError('Account changed');
      if (generation < (history['confirmed'] as int? ?? 0)) {
        throw StateError('Stale chat history settings');
      }
      state['confirmed'] = value;
      final ack = state['offAck'];
      final accountRevision = ack?['accountRevision'],
          policyRevision = ack?['policyRevision'];
      if (ack != null &&
          ack['familyId'] == value['familyId'] &&
          ack['epoch'] == value['epoch'] &&
          value['account']['enabled'] == true &&
          value['policy']['enabled'] == true &&
          (accountRevision is int || policyRevision is int) &&
          (accountRevision == null ||
              value['account']['revision'] > accountRevision) &&
          (policyRevision == null ||
              value['policy']['revision'] > policyRevision) &&
          state['account'] == null &&
          state['policy']?['legacyRemoved'] != true &&
          _revokingMutations == 0 &&
          _failedClosed.isEmpty) {
        state['opening'] = {'token': ack['token'], 'source': 'remoteOn'};
      }
    });
    if (!_current) throw StateError('Account changed');
    _adopt(updated);
    _fresh = true;
    _denied = false;
    return value;
  }

  bool _matches(Map config, Map changes) =>
      (changes['accountEnabled'] == null ||
          config['account']['enabled'] == changes['accountEnabled']) &&
      (changes['retention'] == null ||
          config['policy']['retention'] == changes['retention']);

  Future<void> _updateCommand(
    String kind,
    String id,
    void Function(Map<String, dynamic>) change,
  ) async {
    if (!_current) return;
    final updated = await store.update(uid, (state) {
      if (state[kind]?['id'] == id) change(state);
    });
    if (_current) {
      _adopt(updated);
      _changed();
    }
  }

  Future<void> _pass() async {
    var config = await _fetch();
    for (final kind in ['account', 'policy']) {
      if (!_current) return;
      final command = _state[kind] as Map?;
      if (command == null || command['conflict'] != null) continue;
      final id = command['id'] as String, changes = command['changes'] as Map;
      if (kind == 'policy' &&
          (command['familyId'] != config['familyId'] ||
              command['epoch'] != config['epoch'] ||
              config['canManage'] != true &&
                  changes['initializeIfAbsent'] != true)) {
        await _updateCommand(kind, id, (state) {
          state[kind]['conflict'] = 'scope';
        });
        continue;
      }
      final revision =
          config[kind == 'account' ? 'account' : 'policy']['revision'] as int;
      var expected = command['expectedRevision'] as int?;
      if (changes['initializeIfAbsent'] == true &&
              config['policyConfigured'] == true ||
          changes['initializeIfAbsent'] != true &&
              _matches(config, changes) &&
              expected != null &&
              revision > expected) {
        await _finishCommand(kind, id, config);
        continue;
      }
      final isOff = changes['accountEnabled'] == false;
      if (expected != null &&
          expected != revision &&
          !isOff &&
          changes['initializeIfAbsent'] != true) {
        await _updateCommand(kind, id, (state) {
          state[kind]['conflict'] = 'revision';
        });
        continue;
      }
      expected = changes['initializeIfAbsent'] == true ? 0 : revision;
      await _updateCommand(kind, id, (state) {
        state[kind]['expectedRevision'] = expected;
      });
      if (!_current || _state[kind]?['id'] != id) {
        _again = true;
        continue;
      }
      await api.call('configureFamilyChat', {
        ...Map<String, Object?>.from(changes),
        'expectedRevision': expected,
      });
      if (!_current) return;
      config = await _fetch();
      if (_matches(config, changes) ||
          changes['initializeIfAbsent'] == true &&
              config['policyConfigured'] == true) {
        await _finishCommand(kind, id, config);
      } else {
        await _updateCommand(kind, id, (state) {
          state[kind]['conflict'] = 'changed';
        });
      }
    }
  }

  Future<void> _finishCommand(
    String kind,
    String id,
    Map<String, dynamic> config,
  ) => _updateCommand(kind, id, (state) {
    final command = state[kind], changes = command['changes'];
    if (changes['accountEnabled'] == true) {
      state['opening'] = {'token': command['localToken'], 'intentId': id};
    }
    if (changes['accountEnabled'] == false) {
      state['offAck'] = {
        'token': command['localToken'],
        'familyId': config['familyId'],
        'epoch': config['epoch'],
        'accountRevision': config['account']['enabled'] == false
            ? config['account']['revision']
            : null,
        'policyRevision': config['policy']['enabled'] == false
            ? config['policy']['revision']
            : null,
      };
    }
    state.remove(kind);
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
