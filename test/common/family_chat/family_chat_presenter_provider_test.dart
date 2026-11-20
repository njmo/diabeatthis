import 'dart:async';

import 'package:diabeatthis/common/family_chat/application/family_chat_background.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_consumption_action.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_notification_platform.dart';
import 'package:diabeatthis/common/family_chat/notifications/family_chat_presenter.dart';
import 'package:diabeatthis/common/family_chat/notifications/family_chat_presenter_provider.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/l10n/application_language_storage_keys.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/notifications/controllers/local_notifications_controller.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';
import 'package:diabeatthis/core/notifications/providers/local_notifications_controller_provider.dart';
import 'package:diabeatthis/core/notifications/providers/local_notifications_plugin_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Plugin implements FlutterLocalNotificationsPlugin {
  final shown =
      <
        ({
          int id,
          String? tag,
          String? payload,
          String? title,
          String? body,
          AndroidNotificationDetails? android,
        })
      >[];
  final cancelled = <({int id, String? tag})>[];

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    shown.add((
      id: id,
      tag: notificationDetails?.android?.tag,
      payload: payload,
      title: title,
      body: body,
      android: notificationDetails?.android,
    ));
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelled.add((id: id, tag: tag));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) return Future<bool?>.value(true);
    return super.noSuchMethod(invocation);
  }
}

class _Controller extends LocalNotificationsController {
  _Controller() : super(_Plugin());
  final events = <NotificationEvent>[];
  final cancelled = <({int id, String? tag})>[];
  int initialized = 0;
  bool failCancel = false;

  @override
  Future<void> initializeDelivery() async {
    initialized++;
  }

  @override
  Future<void> show(NotificationEvent event) async => events.add(event);

  @override
  Future<void> cancel(int id, {String? tag}) async {
    if (failCancel) throw StateError('OS unavailable');
    cancelled.add((id: id, tag: tag));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LanguageStrings.setSelectedLocale(null));
  const view = FamilyChatPushView(
    {'uid': 'child', 'scope': 'scope', 'stamp': 'stamp'},
    {'serverTime': 1000},
    {'id': 'question', 'kind': 'question'},
    'caregiver',
  );

  test(
    'chat uses the existing controller override, without a plugin bypass',
    () async {
      final controller = _Controller();
      final container = ProviderContainer(
        overrides: [
          localNotificationsControllerProvider.overrideWithValue(controller),
          localNotificationsPluginProvider.overrideWith(
            (_) => throw StateError('Plugin bypass'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final presenter = container.read(familyChatPresenterProvider);
      const notice = (id: 123, tag: 'scope:message');
      await presenter.replyCompleted(notice, view);
      await presenter.cancel(notice);
      expect(controller.initialized, 1);
      expect(controller.events.single.type.name, 'familyChat');
      expect(controller.cancelled, [notice]);
    },
  );

  test(
    'durable cancellation uses the controller and retains failed intents',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final controller = _Controller()..failCancel = true;
      const notice = (id: 123, tag: 'scope:message');
      await db.rememberNotification(
        'scope',
        notice.id,
        'stamp',
        tag: notice.tag,
      );
      await db.clearScope('scope');
      expect(await db.hasCancellationIntent(notice), true);
      await FamilyChatNotificationPlatform.cancel(
        db,
        [notice],
        controller: controller,
        keepTrying: () => false,
      );
      expect(await db.hasCancellationIntent(notice), true);
      controller.failCancel = false;
      await FamilyChatNotificationPlatform.cancel(db, [
        notice,
      ], controller: controller);
      expect(controller.cancelled, [notice]);
      expect(await db.hasCancellationIntent(notice), false);
      expect(controller.initialized, 0);
    },
  );

  for (final code in ['en', 'pl']) {
    test(
      'headless $code notification statuses and choices follow saved language',
      () async {
        final english = code == 'en';
        SharedPreferences.setMockInitialValues({
          applicationLanguageCodeKey: code,
        });
        setLanguageStringsFromCode(english ? 'pl' : 'en');
        final plugin = _Plugin();
        final container = ProviderContainer(
          overrides: [
            localNotificationsPluginProvider.overrideWithValue(plugin),
          ],
        );
        addTearDown(container.dispose);
        final presenter = container.read(familyChatPresenterProvider);
        const notice = (id: 42, tag: 'scope:question');
        await presenter.replyCompleted(notice, view);
        expect(
          plugin.shown.last.title,
          english ? 'Reply sent' : 'Odpowiedź wysłana',
        );
        expect(plugin.shown.last.android!.silent, true);
        expect(plugin.shown.last.android!.actions, isEmpty);
        expect(plugin.shown.last.android!.timeoutAfter, 1000);
        await presenter.pending(view, needsTicket: false);
        expect(
          plugin.shown.last.title,
          english ? 'Reply waiting to send' : 'Odpowiedź oczekuje na wysłanie',
        );
        expect(
          plugin.shown.last.body,
          contains(english ? 'saved on this device' : 'zapisana na urządzeniu'),
        );
        await presenter.pending(view, needsTicket: true);
        expect(
          plugin.shown.last.title,
          english ? 'Reply not sent' : 'Odpowiedź nie została wysłana',
        );
        await presenter.consumptionStatus(
          notice,
          view.payload,
          FamilyConsumptionNotice.recordedAwaitingAck,
        );
        expect(
          plugin.shown.last.title,
          english ? 'Low treatment recorded' : 'Zapisano dosłodzenie',
        );
        expect(
          plugin.shown.last.body,
          contains(
            english ? 'Confirmation is waiting' : 'Potwierdzenie oczekuje',
          ),
        );
        expect(plugin.shown.last.android!.actions, isEmpty);
        expect(plugin.shown.last.id, notice.id);
        expect(plugin.shown.last.tag, notice.tag);

        for (final state in FamilyConsumptionNotice.values) {
          await presenter.consumptionStatus(notice, view.payload, state);
          final expectedTitle = switch (state) {
            FamilyConsumptionNotice.recorded ||
            FamilyConsumptionNotice.recordedAwaitingAck =>
              english ? 'Low treatment recorded' : 'Zapisano dosłodzenie',
            FamilyConsumptionNotice.completedElsewhere =>
              english
                  ? 'Treatment already confirmed'
                  : 'Dosłodzenie zostało już potwierdzone',
            FamilyConsumptionNotice.anotherDevice =>
              english
                  ? 'Another device is handling confirmation'
                  : 'Potwierdzenie obsługuje inne urządzenie',
            _ =>
              english
                  ? 'Low treatment not recorded'
                  : 'Nie zapisano dosłodzenia',
          };
          final expectedBody = switch (state) {
            FamilyConsumptionNotice.recorded => '',
            FamilyConsumptionNotice.recordedAwaitingAck =>
              english ? 'waiting for a connection' : 'oczekuje na połączenie',
            FamilyConsumptionNotice.completedElsewhere =>
              english
                  ? 'No additional entry'
                  : 'Nie utworzono dodatkowego wpisu',
            FamilyConsumptionNotice.anotherDevice =>
              english ? 'No new entry' : 'Nie utworzono nowego wpisu',
            FamilyConsumptionNotice.pending =>
              english
                  ? 'Consumption has not been recorded'
                  : 'Spożycie nie jest zapisane',
            FamilyConsumptionNotice.unavailable =>
              english ? 'could not be recorded' : 'Nie udało się zapisać',
          };
          expect(plugin.shown.last.title, expectedTitle);
          expect(
            plugin.shown.last.body,
            expectedBody.isEmpty ? isEmpty : contains(expectedBody),
          );
          expect(plugin.shown.last.android!.silent, true);
          expect(plugin.shown.last.android!.actions, isEmpty);
          expect(plugin.shown.last.android!.timeoutAfter, switch (state) {
            FamilyConsumptionNotice.recorded ||
            FamilyConsumptionNotice.completedElsewhere => 5000,
            FamilyConsumptionNotice.pending => 30000,
            _ => 86400000,
          });
          expect(plugin.shown.last.id, notice.id);
          expect(plugin.shown.last.tag, notice.tag);
        }

        final config = <String, dynamic>{
          'serverTime': 1000,
          'epoch': 'epoch',
          'account': {'offGeneration': 0},
          'policy': {'offGeneration': 0},
          'members': [
            {'uid': 'child', 'role': 'child'},
            {'uid': 'caregiver', 'role': 'managingCaregiver'},
          ],
        };
        final message = <String, dynamic>{
          'id': 'question',
          'kind': 'lowTreatment',
          'text': 'Zjedz 1 szt. Frozen product · 6,5 g WW (zapis: 7 g)',
          'senderUid': 'caregiver',
          'sentAt': 900,
          'treatment': {
            'foodName': 'Frozen product',
            'quantity': 1,
            'unit': 'piece',
            'gramsPerUnit': 5,
            'carbsPer100g': 130,
            'carbsPerUnit': 6.5,
            'carbs': 6.5,
            'validUntil': 6000,
          },
        };
        final treatmentView = FamilyChatPushView(
          view.guard,
          config,
          message,
          'family',
        );
        await presenter.show(treatmentView);
        expect(
          plugin.shown.last.body,
          english
              ? 'Eat 1 pc · Frozen product'
              : 'Zjedz 1 szt. · Frozen product',
        );
        expect(
          message['text'],
          'Zjedz 1 szt. Frozen product · 6,5 g WW (zapis: 7 g)',
        );
        final actions = plugin.shown.last.android!.actions!;
        expect(
          AndroidFamilyChatPresenter.messageEvent(treatmentView).replyChoices,
          isEmpty,
        );
        expect(
          actions.map((action) => action.title),
          english
              ? ['I ate it', "I don't have it", 'I feel fine']
              : ['Zjadłem', 'Nie mam', 'Czuję się dobrze'],
        );
        expect(actions.last.inputs, isEmpty);

        final confirmed = AndroidFamilyChatPresenter.messageEvent(
          FamilyChatPushView(
            view.guard,
            {
              ...config,
              'members': [
                {'uid': view.guard['uid'], 'role': 'managingCaregiver'},
              ],
            },
            {
              ...message,
              'kind': 'treatmentResult',
              'replyTo': 'request',
              'names': {message['senderUid']: 'Nemo'},
            },
            'family',
          ),
        );
        expect(confirmed.openRequest, isTrue);
        expect(confirmed.body, isEmpty);
        expect(
          confirmed.title,
          english
              ? 'Nemo · Low treatment confirmed'
              : 'Nemo · Dosłodzenie potwierdzone',
        );

        await presenter.show(
          FamilyChatPushView(view.guard, config, {
            ...message,
            'kind': 'question',
            'answers': ['Zjadłem', 'Nie mam'],
          }, 'family'),
        );
        expect(plugin.shown.last.body, message['text']);
        expect(plugin.shown.last.android!.actions!.map((action) => action.id), [
          'family_chat_reply',
          'family_chat_answer_0',
          'family_chat_answer_1',
        ]);
        expect(
          plugin.shown.last.android!.actions!
              .singleWhere((action) => action.id == 'family_chat_reply')
              .inputs
              .single
              .choices,
          ['Zjadłem', 'Nie mam'],
        );
        await presenter.show(
          FamilyChatPushView(view.guard, config, {
            ...message,
            'kind': 'question',
            'answers': ['Mam', 'Skończyła się', 'Kupię'],
          }, 'family'),
        );
        expect(
          plugin.shown.last.android!.actions!
              .skip(1)
              .map((action) => action.title),
          ['Mam', 'Skończyła się', 'Kupię'],
        );
        expect(
          plugin.shown.last.android!.actions!.first.inputs.single.choices,
          ['Mam', 'Skończyła się', 'Kupię'],
        );
        for (final invalid in [
          <String, dynamic>{'validUntil': 6000},
          {...message['treatment'] as Map, 'quantity': 0},
          {...message['treatment'] as Map, 'unit': 'box'},
        ]) {
          await presenter.show(
            FamilyChatPushView(view.guard, config, {
              ...message,
              'treatment': invalid,
            }, 'family'),
          );
          expect(plugin.shown.last.body, message['text']);
        }
      },
    );
  }

  test(
    'foreground borrows the overridden plugin and preserves exact ID and tag',
    () async {
      final plugin = _Plugin();
      var disposed = false;
      final container = ProviderContainer(
        overrides: [
          localNotificationsPluginProvider.overrideWith((ref) {
            ref.onDispose(() => disposed = true);
            return plugin;
          }),
        ],
      );
      addTearDown(container.dispose);
      final presenter = container.read(familyChatPresenterProvider);
      await withFamilyChatPresenter(
        (borrowed) async {
          expect(identical(borrowed, presenter), true);
          for (final tag in ['first', 'second']) {
            final notice = (id: 123, tag: tag);
            await borrowed.replyCompleted(notice, view);
            await borrowed.cancel(notice);
          }
        },
        presenter: presenter,
        createHeadlessContainer: () => throw StateError('Must borrow'),
      );
      expect(disposed, false);
      expect(plugin.shown.map((item) => (id: item.id, tag: item.tag)), [
        (id: 123, tag: 'first'),
        (id: 123, tag: 'second'),
      ]);
      expect(plugin.cancelled, [
        (id: 123, tag: 'first'),
        (id: 123, tag: 'second'),
      ]);
      expect(
        plugin.shown.every((item) => item.payload!.contains('question')),
        true,
      );
    },
  );

  for (final fails in [false, true]) {
    test(
      'headless container lives until async operation completes (fails=$fails)',
      () async {
        final plugin = _Plugin();
        final entered = Completer<void>();
        final release = Completer<void>();
        var disposed = false;
        ProviderContainer? ownedContainer;
        final operation = withFamilyChatPresenter(
          (presenter) async {
            expect(
              identical(
                presenter.controller,
                ownedContainer!.read(notificationsControllerHeadlessProvider),
              ),
              true,
            );
            entered.complete();
            await release.future;
            expect(disposed, false);
            if (fails) throw StateError('Operation failed');
            const notice = (id: 456, tag: 'headless');
            await presenter.replyCompleted(notice, view);
            await presenter.cancel(notice);
          },
          createHeadlessContainer: () => ownedContainer = ProviderContainer(
            overrides: [
              localNotificationsPluginProvider.overrideWith((ref) {
                ref.onDispose(() => disposed = true);
                return plugin;
              }),
            ],
          ),
        );
        final expectation = fails
            ? expectLater(operation, throwsStateError)
            : expectLater(operation, completes);
        await entered.future;
        expect(disposed, false);
        release.complete();
        await expectation;
        expect(disposed, true);
        expect(
          plugin.cancelled,
          fails ? isEmpty : [(id: 456, tag: 'headless')],
        );
      },
    );
  }
}
