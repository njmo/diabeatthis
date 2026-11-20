import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart';

import '../../../features/low_treatment/presentation/widgets/quick_low_treatment_selection.dart';
import '../../../features/low_treatment/presentation/widgets/quick_low_treatment_tile.dart';
import '../../backend/authenticated_callable_transport.dart';
import '../../l10n/language.dart';
import '../application/confirm_family_treatment.dart';
import '../application/family_chat_session.dart';
import '../application/resolve_family_chat_replies.dart';
import '../domain/family_treatment_authorization.dart';
import '../domain/family_treatment_carbs.dart';
import 'family_chat_settings_section.dart';
import 'family_treatment_text.dart';

import 'shortcut_emoji_picker.dart';

const _accent = Color(0xFF0EA5E9);

/// Protocol answers of a low-treatment request. They are sent back as reply
/// tokens and must stay stable; only their on-screen label is localized.
const _treatmentAteAnswer = 'Zjadłem';
const _maxQuestionAnswers = 3;
const _treatmentNoneAnswer = 'Nie mam';
const _treatmentFeelsWellAnswer = 'Czuję się dobrze';

String _answerLabel(_Message message, String answer, AppLocalizations lang) {
  if (message.lowTreatment == null && message.treatmentReplyIcon == null) {
    return answer;
  }
  return switch (answer) {
    _treatmentAteAnswer => lang.familyChatTreatmentAnswerAte,
    _treatmentNoneAnswer => lang.familyChatTreatmentAnswerNone,
    _treatmentFeelsWellAnswer => lang.familyChatTreatmentAnswerFeelsWell,
    _ => answer,
  };
}

/// Treatment snapshots carry unit codes (`piece`, `portion`, `g`, `ml`).
/// Legacy Polish labels are accepted for food choices built elsewhere.
String _unitLabel(String unit, AppLocalizations lang) =>
    familyTreatmentUnitLabel(unit, lang);

String _quantityLabel(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString().replaceAll('.', ',');

Future<T?> _showChatForm<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final base = Theme.of(context);
  final dark = base.brightness == Brightness.dark;
  final background = dark ? const Color(0xFF0F172A) : const Color(0xFFF6F8FA);
  final field = dark ? const Color(0xFF1E293B) : Colors.white;
  final foreground = dark ? const Color(0xFFF1F5F9) : const Color(0xFF27313D);
  final muted = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
  );
  final theme = base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _accent,
      onPrimary: Colors.white,
      surface: background,
      onSurface: foreground,
      onSurfaceVariant: muted,
      surfaceContainerHighest: field,
    ),
    textTheme: base.textTheme
        .apply(bodyColor: foreground, displayColor: foreground)
        .copyWith(
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            color: foreground,
            fontSize: 14,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            color: foreground,
            fontSize: 14,
          ),
        ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: _accent),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: base.colorScheme.error),
      ),
      labelStyle: TextStyle(color: muted, fontSize: 13),
      hintStyle: TextStyle(color: muted, fontSize: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: field,
        minimumSize: const Size(0, 44),
        side: BorderSide(color: muted.withValues(alpha: .2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
  );
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => Theme(data: theme, child: builder(context)),
  );
}

class _ChatFormHeader extends StatelessWidget {
  const _ChatFormHeader({
    required this.title,
    required this.icon,
    this.subtitle,
  });
  final String title;
  final IconData icon;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _accent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: context.lang.familyChatCloseForm,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ],
    ),
  );
}

class _Question {
  const _Question(this.label, this.text, this.answers, this.emoji, {this.id});
  final String? id;
  final String label;
  final String text;
  final List<String> answers;
  final String emoji;
}

class _LowTreatmentRequest {
  const _LowTreatmentRequest(
    this.product,
    this.quantity,
    this.carbs, {
    this.unit = 'piece',
    this.gramsPerUnit,
    this.validUntil,
    this.sourceCarbsPerUnit,
  });
  final String product;
  final double quantity;
  final double carbs;
  final String unit;
  final double? gramsPerUnit;
  final int? validUntil;
  final double? sourceCarbsPerUnit;
  int get deliveryCarbs =>
      carbs >= .5 ? familyTreatmentRecordedCarbs(carbs) : 0;
  Map<String, Object?> snapshot(int serverNow) {
    final mass = gramsPerUnit;
    final perUnit = sourceCarbsPerUnit ?? carbs / quantity;
    return {
      'foodName': product,
      'quantity': quantity,
      'unit': mass == null
          ? 'portion'
          : ['g', 'ml'].contains(unit)
          ? unit
          : 'piece',
      'gramsPerUnit': mass,
      'carbsPer100g': mass == null ? null : perUnit * 100 / mass,
      'carbsPerUnit': perUnit,
      'validUntil': serverNow + const Duration(minutes: 30).inMilliseconds,
    };
  }

  factory _LowTreatmentRequest.fromSnapshot(Map value) => _LowTreatmentRequest(
    value['foodName'] as String,
    (value['quantity'] as num).toDouble(),
    (value['carbs'] as num?)?.toDouble() ??
        (value['quantity'] as num).toDouble() *
            (value['unit'] == 'portion'
                ? (value['carbsPerUnit'] as num).toDouble()
                : (value['gramsPerUnit'] as num).toDouble() *
                      (value['carbsPer100g'] as num).toDouble() /
                      100),
    unit: value['unit'] as String,
    gramsPerUnit: (value['gramsPerUnit'] as num?)?.toDouble(),
    sourceCarbsPerUnit: (value['carbsPerUnit'] as num?)?.toDouble(),
    validUntil: value['validUntil'] as int,
  );
  String textFor(AppLocalizations lang) => familyTreatmentText(
    lang,
    product: product,
    quantity: quantity,
    unit: unit,
    carbs: carbs,
  );
}

/// A read-only product snapshot. Quantity is chosen by the caregiver.
class FamilyChatFoodChoice {
  const FamilyChatFoodChoice({
    required this.name,
    required this.unit,
    required this.carbsPerUnit,
    this.initialAmount,
    this.gramsPerUnit,
    this.iconAssetPath,
    this.quickShortcut = false,
  });
  final String name;
  final String unit;
  final double carbsPerUnit;
  final double? initialAmount;
  final double? gramsPerUnit;
  final String? iconAssetPath;
  final bool quickShortcut;
}

enum _DeliveryState { pending, sent, delivered, read, failed }

String _deliveryLabel(_DeliveryState state, AppLocalizations lang) =>
    switch (state) {
      _DeliveryState.pending => lang.familyChatDeliveryPending,
      _DeliveryState.sent => lang.familyChatDeliverySent,
      _DeliveryState.delivered => lang.familyChatDeliveryDelivered,
      _DeliveryState.read => lang.familyChatDeliveryRead,
      _DeliveryState.failed => lang.familyChatDeliveryFailed,
    };

class _Message {
  _Message(
    this.text, {
    required this.mine,
    this.sender = '',
    this.answers = const [],
    this.isQuestion = false,
    this.lowTreatment,
    this.delivery = _DeliveryState.sent,
    required this.createdAt,
    this.id,
    this.wasRead = false,
    this.treatmentComplete = false,
    this.authorization,
    this.sendOutcomeUnknown = false,
    this.redactedOutcome = false,
    this.treatmentSnapshot,
  });
  final String? id;
  final bool wasRead;
  final bool treatmentComplete;
  final FamilyTreatmentAuthorization? authorization;
  final bool sendOutcomeUnknown;
  final bool redactedOutcome;

  /// Set only for kind `lowTreatment` rows. The body is rendered from this
  /// snapshot in the viewer locale once validated; the stored text (canonical
  /// backend body) is left untouched and remains the fallback.
  final Map? treatmentSnapshot;
  final String text;
  final bool mine;
  final String sender;
  final List<String> answers;
  final bool isQuestion;
  final _LowTreatmentRequest? lowTreatment;
  final DateTime createdAt;
  final _DeliveryState delivery;
  List<_RecipientReceipt>? groupReceipts;
  String? reply;
  bool? selectedReply;
  IconData? treatmentReplyIcon;
  ({String text, Object? treatment, DateTime sentAt})? replyContext;
}

class _RecipientReceipt {
  const _RecipientReceipt(
    this.name,
    this.state, {
    required this.isChild,
    this.readAt,
  });
  final String name;
  final bool isChild;
  final _DeliveryState state;
  final DateTime? readAt;
}

String _receiptTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// A family conversation backed by an authenticated session.
class FamilyChatConversation extends StatefulWidget {
  const FamilyChatConversation({
    super.key,
    required this.isCaregiver,
    this.loadFoods,
    this.showTreatmentAction = true,
    required this._session,
    this.initialTarget,
    this.confirmTreatment,
    this.confirmTreatmentQuantity,
    this.confirmTreatmentWithAuthorization,
    this.loadTreatmentResult,
    this.loadTreatmentQuantity,
  });

  final bool isCaregiver;
  final bool showTreatmentAction;
  final FamilyChatSession _session;
  final String? initialTarget;
  final Future<FamilyTreatmentResult> Function(String id)? confirmTreatment;
  final Future<FamilyTreatmentResult> Function(String id, double quantity)?
  confirmTreatmentQuantity;
  final Future<FamilyTreatmentResult> Function(
    String id,
    double? quantity,
    FamilyTreatmentAuthorization? authorization,
  )?
  confirmTreatmentWithAuthorization;
  final Future<FamilyTreatmentResult?> Function(String id)? loadTreatmentResult;
  final Future<double?> Function(String id)? loadTreatmentQuantity;
  final Future<List<FamilyChatFoodChoice>> Function()? loadFoods;

  @override
  State<FamilyChatConversation> createState() => _FamilyChatConversationState();
}

class _FamilyChatConversationState extends State<FamilyChatConversation> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messageKeys = <String, GlobalKey>{};
  final _messageViewport = GlobalKey();
  final _readQueued = <String>{};
  final _treatmentInFlight = <String>{}, _treatmentLookups = <String>{};
  final _treatmentResults = <String, FamilyTreatmentResult>{};
  final _treatmentQuantities = <String, double>{};
  final _treatmentHydrated = <String>{};
  final _treatmentErrors = <String, String>{};
  Timer? _draftTimer;
  bool _readScheduled = false;
  bool _initialScrollPending = false;
  bool _scrollingToLatest = false;
  final _positionedTargets = <String>{};
  int _scrollJumpRevision = 0;
  bool _sendingComposer = false;
  String? _submittedComposerTarget;
  String? _submittedComposerRaw;
  bool _submittedComposerQuestion = false;
  final _composerCooldown = Stopwatch();
  final _replyInFlight = <String>{};
  String? _lastRenderedMessage;
  final _quickReplies = <_Question>[];
  final _questions = <_Question>[];

  List<_Question> _defaultQuickReplies(AppLocalizations lang) => [
    _Question(
      lang.familyChatShortcutLookingNow,
      lang.familyChatShortcutLookingNow,
      const [],
      '👀',
    ),
    _Question(
      lang.familyChatShortcutReplyAtBreak,
      lang.familyChatShortcutReplyAtBreak,
      const [],
      '⏰',
    ),
    _Question(
      lang.familyChatShortcutAllGood,
      lang.familyChatShortcutAllGood,
      const [],
      '👍',
    ),
  ];
  List<_Question> _defaultQuestions(AppLocalizations lang) => [
    _Question(
      lang.familyChatQuestionBreakfastLabel,
      lang.familyChatQuestionBreakfastText,
      [
        lang.familyChatQuestionBreakfastAnswerHave,
        lang.familyChatQuestionBreakfastAnswerNone,
        lang.familyChatQuestionBreakfastAnswerCheck,
      ],
      '🥪',
    ),
    _Question(
      lang.familyChatQuestionWaterLabel,
      lang.familyChatQuestionWaterText,
      [
        lang.familyChatQuestionWaterAnswerHave,
        lang.familyChatQuestionWaterAnswerRanOut,
        lang.familyChatQuestionWaterAnswerBuy,
      ],
      '💧',
    ),
    _Question(
      lang.familyChatQuestionFeelingLabel,
      lang.familyChatQuestionFeelingText,
      [
        lang.familyChatQuestionFeelingAnswerGood,
        lang.familyChatQuestionFeelingAnswerSoso,
        lang.familyChatQuestionFeelingAnswerCall,
      ],
      '🙂',
    ),
    _Question(
      lang.familyChatQuestionBreakLabel,
      lang.familyChatQuestionBreakText,
      [
        lang.familyChatQuestionBreakAnswerYes,
        lang.familyChatQuestionBreakAnswerAtBreak,
        lang.familyChatQuestionBreakAnswerCall,
      ],
      '⏰',
    ),
  ];
  late String _recipient;
  bool _savingShortcuts = false;
  List<_Question> _confirmedShortcuts = [];
  List<_Question> get _activeShortcuts =>
      widget.isCaregiver ? _questions : _quickReplies;

  void _loadShortcuts() {
    final saved = widget._session.shortcuts;
    final entries = _activeShortcuts;
    if (saved != null) {
      entries
        ..clear()
        ..addAll(
          saved.map(
            (item) => _Question(
              item['label'] as String,
              item['text'] as String,
              List<String>.from(item['answers'] as List),
              item['emoji'] as String,
              id: item['id'] as String,
            ),
          ),
        );
    } else if (entries.isEmpty) {
      final activeLang = context.lang;
      if (widget.isCaregiver) {
        entries.addAll(_defaultQuestions(activeLang));
      } else {
        entries.addAll(_defaultQuickReplies(activeLang));
      }
    }
    for (var index = 0; index < entries.length; index++) {
      final item = entries[index];
      if (item.id == null) {
        entries[index] = _Question(
          item.label,
          item.text,
          item.answers,
          item.emoji,
          id: 'default-${widget.isCaregiver ? 'q' : 'r'}-$index',
        );
      }
    }
    _confirmedShortcuts = List.of(entries);
  }

  String _shortcutId() =>
      's-${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}';
  Future<void> _persistShortcuts({bool orderOnly = false}) async {
    final session = widget._session;
    _savingShortcuts = true;
    try {
      await session.saveShortcuts([
        for (final item in _activeShortcuts)
          {
            'id': item.id,
            'label': item.label,
            'text': item.text,
            'answers': item.answers,
            'emoji': item.emoji,
          },
      ], orderOnly: orderOnly);
      _loadShortcuts();
    } catch (_) {
      _activeShortcuts
        ..clear()
        ..addAll(_confirmedShortcuts);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.familyChatSaveShortcutsFailed)),
        );
      }
    } finally {
      _savingShortcuts = false;
      if (mounted) setState(() {});
    }
  }

  List<String> get _recipients => widget._session.targets;
  String _recipientName(String id) => id == 'family'
      ? context.lang.familyChatRecipientFamily
      : widget._session.name(id);
  bool get _group => _recipient == 'family';

  /// The child whose answer can close a question in [target]. Unresolvable
  /// (several children in a group) yields '', which authorizes no answer.
  String _childUid(FamilyChatSession session, String target) {
    final children = {
      for (final member in session.members)
        if (member['role'] == 'child' && member['uid'] is String)
          member['uid'] as String,
    };
    if (children.contains(session.uid)) return session.uid;
    if (children.contains(target)) return target;
    return children.length == 1 ? children.single : '';
  }

  List<_Message> _remoteMessages(FamilyChatSession session, {String? target}) {
    final rows = session.messages(target ?? _recipient);
    const resolve = ResolveFamilyChatReplies();
    final replies = resolve(rows);
    final questionStates = resolve.questionStates(
      rows,
      childUid: _childUid(session, target ?? _recipient),
    );
    final rowsById = {
      for (final row in rows)
        if (row['id'] is String) row['id'] as String: row,
    };
    final shownTreatmentAnswers = <(Object?, Object?, Object?)>{};
    final messages = rows
        .where((row) {
          final parent = rowsById[row['replyTo']];
          if (parent?['kind'] != 'lowTreatment' ||
              row['kind'] != 'answer' ||
              row['delivery'] == 'failed' ||
              row['redactedOutcome'] == true) {
            return true;
          }
          return shownTreatmentAnswers.add((
            row['replyTo'],
            row['senderUid'],
            row['text'],
          ));
        })
        .map((row) {
          final receipts = row['receipts'] as Map? ?? {};
          _DeliveryState state(Map receipt) => receipt['readAt'] != null
              ? _DeliveryState.read
              : receipt['deliveredAt'] != null
              ? _DeliveryState.delivered
              : _DeliveryState.sent;
          final values = receipts.values.map((v) => state(v as Map)).toList();
          final delivery = row['delivery'] == 'pending'
              ? _DeliveryState.pending
              : row['delivery'] == 'failed'
              ? _DeliveryState.failed
              : values.isNotEmpty &&
                    values.every((v) => v == _DeliveryState.read)
              ? _DeliveryState.read
              : values.isNotEmpty &&
                    values.every(
                      (v) =>
                          v == _DeliveryState.delivered ||
                          v == _DeliveryState.read,
                    )
              ? _DeliveryState.delivered
              : _DeliveryState.sent;
          final message = _Message(
            row['text'] as String,
            id: row['id'] as String,
            authorization: familyTreatmentAuthorizationFromConfig(
              session.config ?? {},
            ),
            mine: row['senderUid'] == session.uid,
            sender:
                (row['names'] as Map?)?[row['senderUid']] as String? ??
                session.name(row['senderUid'] as String),
            answers: row['kind'] == 'lowTreatment'
                ? const [
                    _treatmentAteAnswer,
                    _treatmentNoneAnswer,
                    _treatmentFeelsWellAnswer,
                  ]
                : (row['answers'] as List? ?? []).cast<String>(),
            isQuestion: row['kind'] == 'question',
            lowTreatment: row['treatment'] is Map
                ? _LowTreatmentRequest.fromSnapshot(row['treatment'] as Map)
                : null,
            treatmentComplete: row['treatmentResult'] != null,
            treatmentSnapshot:
                row['kind'] == 'lowTreatment' && row['treatment'] is Map
                ? row['treatment'] as Map
                : null,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['sentAt'] as int,
            ),
            delivery: delivery,
            sendOutcomeUnknown: row['sendOutcomeUnknown'] == true,
            redactedOutcome: row['redactedOutcome'] == true,
            wasRead:
                row['_localRead'] == true ||
                (row['receipts'] as Map?)?[session.uid]?['readAt'] != null,
          );
          if (message.lowTreatment != null &&
              !widget.isCaregiver &&
              widget.loadTreatmentResult != null &&
              _treatmentLookups.add(message.id!)) {
            unawaited(
              _reloadTreatmentResult(message.id!).catchError((Object _) {
                _treatmentLookups.remove(message.id);
              }),
            );
          }
          if (message.mine &&
              _group &&
              delivery != _DeliveryState.pending &&
              delivery != _DeliveryState.failed) {
            message.groupReceipts = receipts.entries.map((entry) {
              final value = entry.value as Map;
              return _RecipientReceipt(
                (row['names'] as Map?)?[entry.key] as String? ??
                    session.name(entry.key as String),
                state(value),
                isChild: (row['roles'] as Map?)?[entry.key] == 'child',
                readAt: value['readAt'] == null
                    ? null
                    : DateTime.fromMillisecondsSinceEpoch(
                        value['readAt'] as int,
                      ),
              );
            }).toList();
          }
          if (row['kind'] == 'question') {
            // Shared policy: only the child's confirmed, pending or ambiguous
            // answer closes the question; a definitively failed one reopens it.
            final state = questionStates[row['id']];
            message.reply = state != null && state.blocksNewAnswer
                ? (rowsById[state.replyId]?['text'] as String? ?? '')
                : null;
          } else {
            // Clinical requests keep their own reply/consumption policy.
            message.reply =
                rows
                        .where(
                          (reply) =>
                              reply['replyTo'] == row['id'] &&
                              reply['redactedOutcome'] != true,
                        )
                        .lastOrNull?['text']
                    as String?;
          }
          final parent = rowsById[row['replyTo']];
          final treatmentAnswer =
              row['kind'] == 'answer' && parent?['kind'] == 'lowTreatment';
          final treatmentResult = row['kind'] == 'treatmentResult';
          if (treatmentResult || treatmentAnswer) {
            message.treatmentReplyIcon = switch (row['text']) {
              _treatmentNoneAnswer => Icons.cancel_outlined,
              _treatmentFeelsWellAnswer => Icons.sentiment_satisfied_alt,
              _ => Icons.check_circle_rounded,
            };
          }
          message.selectedReply = treatmentAnswer || treatmentResult
              ? false
              : replies[message.id]?.selected;
          if (message.selectedReply != null &&
              parent != null &&
              parent['redactedOutcome'] != true &&
              parent['text'] is String &&
              parent['sentAt'] is int) {
            message.replyContext = (
              text: parent['text'] as String,
              treatment: parent['treatment'],
              sentAt: DateTime.fromMillisecondsSinceEpoch(
                parent['sentAt'] as int,
              ),
            );
          }
          return message;
        })
        .toList();
    return messages;
  }

  List<_Message> get _messages => _remoteMessages(widget._session);

  @override
  void initState() {
    super.initState();
    _recipient = _recipients.contains(widget.initialTarget)
        ? widget.initialTarget!
        : _recipients.first;
    _input.text = widget._session.draft(_recipient);
    _input.addListener(_updateComposer);
    _scroll.addListener(_scheduleRead);
    _jumpToLatest();
  }

  @override
  void didUpdateWidget(covariant FamilyChatConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final session = widget._session;
    if (session.draftWasExpired(_recipient) &&
        session.draft(_recipient).isEmpty &&
        _input.text.isNotEmpty) {
      _draftTimer?.cancel();
      _input.removeListener(_updateComposer);
      _input.clear();
      _input.addListener(_updateComposer);
    }
  }

  void _updateComposer() {
    if (mounted) setState(() {});
    widget._session.stageDraft(_recipient, _input.text);
    _draftTimer?.cancel();
    final target = _recipient;
    final text = _input.text;
    _draftTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) unawaited(_persistDraft(target, text));
    });
  }

  Future<void> _persistDraft(String target, String text) async {
    try {
      await widget._session.saveDraft(target, text, edited: false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.familyChatSaveDraftFailed)),
        );
      }
    }
  }

  void _scheduleRead() {
    if (_readScheduled || _initialScrollPending || _scrollingToLatest) {
      return;
    }
    _readScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readScheduled = false;
      if (!mounted ||
          ModalRoute.of(context)?.isCurrent != true ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed)) {
        return;
      }
      final visible = <String>{};
      final viewport = _messageViewport.currentContext?.findRenderObject();
      if (viewport is! RenderBox || !viewport.hasSize) return;
      final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
      for (final message in _messages) {
        for (final candidate in [message]) {
          if (candidate.mine || candidate.wasRead || candidate.id == null) {
            continue;
          }
          final render = _messageKeys[candidate.id]?.currentContext
              ?.findRenderObject();
          if (render is RenderBox && render.attached && render.hasSize) {
            final rectangle = render.localToGlobal(Offset.zero) & render.size;
            if (rectangle.overlaps(bounds)) {
              if (_readQueued.add(candidate.id!)) {
                visible.add(candidate.id!);
              }
            }
          }
        }
      }
      if (visible.isNotEmpty) {
        final session = widget._session;
        final target = _recipient;
        unawaited(() async {
          try {
            if (!await session.markRead(target, ids: visible)) {
              _readQueued.removeAll(visible);
            }
          } catch (_) {
            _readQueued.removeAll(visible);
          }
        }());
      }
    });
  }

  void _jumpToLatest() {
    _initialScrollPending = true;
    _scrollingToLatest = false;
    final revision = ++_scrollJumpRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _scrollJumpRevision) return;
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.minScrollExtent);
      setState(() => _initialScrollPending = false);
    });
  }

  Future<bool> _sendRemote(
    String text, {
    String kind = 'text',
    List<String> answers = const [],
    String? replyTo,
    int? answerIndex,
    String? composerDraft,
    String? targetUid,
    Map<String, Object?>? treatment,
  }) async {
    try {
      await widget._session.send(
        targetUid ?? _recipient,
        text,
        kind: kind,
        answers: answers,
        replyTo: replyTo,
        answerIndex: answerIndex,
        composerDraft: composerDraft,
        treatment: treatment,
      );
      if (mounted) _toBottom();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.familyChatEnqueueFailed)),
        );
      }
      return false;
    }
  }

  Future<void> _sendComposer({bool question = false}) async {
    final sameSubmission =
        question == _submittedComposerQuestion &&
        _recipient == _submittedComposerTarget &&
        (_input.text == _submittedComposerRaw || _input.text.trim().isEmpty);
    if (_sendingComposer ||
        (sameSubmission &&
            _composerCooldown.isRunning &&
            _composerCooldown.elapsedMilliseconds < 300)) {
      return;
    }
    _composerCooldown.reset();
    _composerCooldown.start();
    _submittedComposerTarget = _recipient;
    _submittedComposerRaw = _input.text;
    _submittedComposerQuestion = question;
    _draftTimer?.cancel();
    setState(() => _sendingComposer = true);
    try {
      await widget._session.saveDraft(_recipient, _input.text, edited: false);
      await _performSendComposer(question: question);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.familyChatSaveMessageFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComposer = false);
    }
  }

  Future<void> _performSendComposer({bool question = false}) async {
    final raw = _submittedComposerRaw ?? _input.text;
    final target = _submittedComposerTarget ?? _recipient;
    if (question) {
      final sent = await _editQuestion(
        text: raw.trim(),
        composerDraft: raw,
        targetUid: target,
      );
      if (sent && mounted && target == _recipient && _input.text == raw) {
        _input.clear();
      }
      return;
    }
    if (raw.trim().isEmpty) {
      await _sendRemote('OK', targetUid: target);
      return;
    }
    await _sendText(snapshotRaw: raw, snapshotTarget: target);
  }

  @override
  void dispose() {
    final submittedSnapshot =
        _sendingComposer &&
        _recipient == _submittedComposerTarget &&
        _input.text == _submittedComposerRaw;
    final session = widget._session;
    if (!submittedSnapshot) {
      unawaited(
        session
            .saveDraft(_recipient, _input.text, edited: false)
            .catchError((Object _) {}),
      );
    }
    _draftTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    _scrollingToLatest = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && _scroll.hasClients) {
        await _scroll.animateTo(
          _scroll.position.minScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
      if (mounted) {
        _scrollingToLatest = false;
        _scheduleRead();
        WidgetsBinding.instance.scheduleFrame();
      }
    });
  }

  Future<bool> _sendQuestion(
    _Question question, {
    String? composerDraft,
    String? targetUid,
  }) async {
    if (question.answers.length > _maxQuestionAnswers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.familyChatQuestionAnswerLimit)),
      );
      return false;
    }
    return _sendRemote(
      question.text,
      kind: 'question',
      answers: question.answers,
      composerDraft: composerDraft,
      targetUid: targetUid,
    );
  }

  void _reply(_Message message, String answer) {
    if (message.lowTreatment != null && answer == _treatmentAteAnswer) {
      unawaited(_consume(message));
      return;
    }
    if (message.id == null || !_replyInFlight.add(message.id!)) return;
    unawaited(() async {
      final queued = await _sendRemote(
        answer,
        kind: 'answer',
        replyTo: message.id,
        answerIndex: message.isQuestion && message.answers.contains(answer)
            ? message.answers.indexOf(answer)
            : null,
      );
      // Questions: once queued, the shared reply policy (pending/unknown
      // blocks, definite failure reopens) owns duplicate protection, so a
      // later definite failure can be answered again. Other rows (clinical
      // requests) keep the one-shot guard of their separate policy.
      if (!queued || message.isQuestion) {
        _replyInFlight.remove(message.id);
        if (mounted) setState(() {});
      }
    }());
  }

  bool _treatmentDone(_Message message) =>
      message.treatmentComplete ||
      _treatmentResults[message.id]?.mealId != null ||
      _treatmentResults[message.id]?.acknowledged == true;
  bool _treatmentExpired(_Message message) =>
      message.lowTreatment?.validUntil != null &&
      message.lowTreatment!.validUntil! <= widget._session.serverNow;
  bool _canReply(_Message message) =>
      !message.mine &&
      (message.lowTreatment != null
          ? (!_treatmentDone(message) &&
                (widget.confirmTreatmentWithAuthorization == null ||
                    message.authorization != null) &&
                (widget.loadTreatmentResult == null ||
                    _treatmentHydrated.contains(message.id)) &&
                message.lowTreatment!.carbs >= .5 &&
                !_treatmentExpired(message) &&
                !_treatmentInFlight.contains(message.id))
          : message.reply == null);

  Future<void> _reloadTreatmentResult(String id) async {
    final result = await widget.loadTreatmentResult?.call(id);
    final quantity = result == null
        ? null
        : await widget.loadTreatmentQuantity?.call(id);
    if (!mounted) return;
    setState(() {
      _treatmentHydrated.add(id);
      if (result != null) _treatmentResults[id] = result;
      if (quantity != null) _treatmentQuantities[id] = quantity;
    });
  }

  Future<void> _chooseConsumedQuantity(_Message message) async {
    final id = message.id;
    if (id == null ||
        !_canReply(message) ||
        _treatmentResults.containsKey(id)) {
      return;
    }
    final quantity = await _showChatForm<double>(
      context,
      builder: (_) => _ConsumedQuantityEditor(request: message.lowTreatment!),
    );
    if (!mounted || quantity == null || !_canReply(message)) return;
    await _consume(message, quantity: quantity);
  }

  Future<void> _consume(_Message message, {double? quantity}) async {
    final id = message.id;
    quantity ??= _treatmentQuantities[id];
    if (id == null ||
        widget.confirmTreatment == null ||
        !widget._session.serverVerified ||
        !_canReply(message) ||
        !_treatmentInFlight.add(id)) {
      return;
    }
    setState(() => _treatmentErrors.remove(id));
    try {
      final result = widget.confirmTreatmentWithAuthorization != null
          ? await widget.confirmTreatmentWithAuthorization!(
              id,
              quantity,
              message.authorization,
            )
          : quantity == null
          ? await widget.confirmTreatment!(id)
          : await widget.confirmTreatmentQuantity!(id, quantity);
      if (!mounted) return;
      setState(() {
        _treatmentResults[id] = result;
        if (quantity != null) _treatmentQuantities[id] = quantity;
      });
      unawaited(widget._session.synchronize().catchError((Object _) {}));
    } catch (error) {
      try {
        await _reloadTreatmentResult(id);
      } catch (_) {
        _treatmentHydrated.remove(id);
        _treatmentLookups.remove(id);
      }
      if (!mounted) return;
      setState(
        () => _treatmentErrors[id] =
            error is CallableFailure &&
                [
                  'consumption-unversioned-intent',
                  'consumption-authorization-unavailable',
                  'consumption-consent-revoked',
                ].contains(error.rejectionCode)
            ? context.lang.familyChatTreatmentRenewRequired
            : error is CallableFailure &&
                  error.rejectionCode == 'already-exists'
            ? context.lang.familyChatTreatmentHandledByOtherDevice
            : error is CallableFailure &&
                  [
                    'not-found',
                    'permission-denied',
                    'failed-precondition',
                  ].contains(error.rejectionCode)
            ? context.lang.familyChatTreatmentUnavailable
            : context.lang.familyChatTreatmentSaveFailed,
      );
    } finally {
      _treatmentInFlight.remove(id);
      if (mounted) setState(() {});
    }
  }

  String? _treatmentStatus(_Message message, AppLocalizations lang) {
    final result = _treatmentResults[message.id];
    if (result?.mealId != null) {
      return result!.acknowledged || message.treatmentComplete
          ? lang.familyChatTreatmentRecorded
          : lang.familyChatTreatmentRecordedPendingNetwork;
    }
    if (message.treatmentComplete) {
      return widget.isCaregiver
          ? lang.familyChatChildConfirmedEating
          : lang.familyChatConfirmedOnChildDevice;
    }
    if (result?.acknowledged == true) {
      return lang.familyChatConfirmedOnOtherDevice;
    }
    if (_treatmentInFlight.contains(message.id)) {
      return lang.familyChatSavingTreatment;
    }
    if (_treatmentErrors[message.id] case final error?) return error;
    if (_treatmentExpired(message)) return lang.familyChatTreatmentExpired;
    if (!widget._session.serverVerified) {
      return lang.familyChatConnectToConfirmConsumption;
    }
    if (result != null) {
      final quantity =
          _treatmentQuantities[message.id] ?? message.lowTreatment!.quantity;
      return lang.familyChatTreatmentQuantityFixedRetry(
        quantity.toString(),
        _unitLabel(message.lowTreatment!.unit, lang),
      );
    }
    return null;
  }

  Future<void> _composeLowTreatment() async {
    final target = _recipient;
    var foods = const <FamilyChatFoodChoice>[];
    try {
      foods = await widget.loadFoods?.call() ?? const [];
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.familyChatLoadFoodsFailed)),
      );
    }
    if (!mounted) return;
    final saved = await showFamilyLowTreatmentComposer(
      context,
      session: widget._session,
      target: target,
      foods: foods,
    );
    if (saved != null && mounted) _toBottom();
  }

  Future<void> _sendText({String? snapshotRaw, String? snapshotTarget}) async {
    final rawText = snapshotRaw ?? _input.text;
    final value = rawText.trim();
    final target = snapshotTarget ?? _recipient;
    if (value.isEmpty) return;
    final pending = widget.isCaregiver
        ? null
        : _remoteMessages(
            widget._session,
            target: target,
          ).where((m) => !m.mine && m.isQuestion && m.reply == null).lastOrNull;
    if (await _sendRemote(
          value,
          kind: pending == null ? 'text' : 'answer',
          replyTo: pending?.id,
          composerDraft: rawText,
          targetUid: target,
        ) &&
        mounted &&
        target == _recipient &&
        _input.text == rawText) {
      _input.clear();
    }
  }

  Future<void> _quickReplyMenu() async {
    _loadShortcuts();
    final entries = _quickReplies;
    final picked = await showDialog<_Question>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .1),
      builder: (_) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: _QuestionWheel(
          questions: entries,
          recipient: _recipientName(_recipient),
          isReply: true,
          onAdd: () async {
            await _editQuickReply(null);
          },
          onEdit: (entry) async {
            await _editQuickReply(entries.indexOf(entry));
          },
          onDelete: (entry) async {
            if (_savingShortcuts) return;
            setState(() => _quickReplies.removeAt(entries.indexOf(entry)));
            await _persistShortcuts();
          },
          onMove: (from, to) async {
            if (_savingShortcuts) return;
            setState(() {
              final reply = _quickReplies[from];
              _quickReplies[from] = _quickReplies[to];
              _quickReplies[to] = reply;
            });
            await _persistShortcuts(orderOnly: true);
          },
        ),
      ),
    );
    if (!mounted || picked == null) return;
    final pending = _messages
        .where((m) => !m.mine && m.isQuestion && m.reply == null)
        .lastOrNull;
    await _sendRemote(
      picked.text,
      kind: pending == null ? 'text' : 'answer',
      replyTo: pending?.id,
    );
  }

  Future<void> _editQuickReply(int? index) async {
    if (_savingShortcuts || index == null && _quickReplies.length >= 6) return;
    final result = await _showChatForm<_Question>(
      context,
      builder: (_) => _QuickReplyEditor(
        initial: index == null ? null : _quickReplies[index],
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (index == null) {
        _quickReplies.add(
          _Question(
            result.label,
            result.text,
            result.answers,
            result.emoji,
            id: _shortcutId(),
          ),
        );
      } else {
        _quickReplies[index] = _Question(
          result.label,
          result.text,
          result.answers,
          result.emoji,
          id: _quickReplies[index].id,
        );
      }
    });
    await _persistShortcuts();
  }

  Future<bool> _editQuestion({
    String text = '',
    _Question? initial,
    bool sendAfterSave = true,
    String? composerDraft,
    String? targetUid,
  }) async {
    final shouldSend = initial == null && sendAfterSave;
    if (!shouldSend && _savingShortcuts) return false;
    final result = await _showChatForm<_Question>(
      context,
      builder: (_) => _QuestionEditor(
        initial: initial,
        text: text,
        sendAfterSave: shouldSend,
      ),
    );
    if (!mounted || result == null) return false;
    setState(() {
      if (initial != null) {
        _questions[_questions.indexOf(initial)] = _Question(
          result.label,
          result.text,
          result.answers,
          result.emoji,
          id: initial.id,
        );
      } else if (!shouldSend && _questions.length < 6) {
        _questions.add(
          _Question(
            result.label,
            result.text,
            result.answers,
            result.emoji,
            id: _shortcutId(),
          ),
        );
      }
    });
    if (shouldSend) {
      return _sendQuestion(
        result,
        composerDraft: composerDraft,
        targetUid: targetUid,
      );
    }
    await _persistShortcuts();
    return true;
  }

  Future<void> _quickQuestions() async {
    _loadShortcuts();
    final picked = await showDialog<_Question>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .1),
      builder: (dialogContext) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: _QuestionWheel(
          questions: _questions,
          recipient: _recipientName(_recipient),
          onAdd: () async {
            await _editQuestion(sendAfterSave: false);
          },
          onEdit: (question) async {
            await _editQuestion(initial: question, sendAfterSave: false);
          },
          onDelete: (question) async {
            if (_savingShortcuts) return;
            setState(() => _questions.remove(question));
            await _persistShortcuts();
          },
          onMove: (from, to) async {
            if (_savingShortcuts) return;
            setState(() {
              final question = _questions[from];
              _questions[from] = _questions[to];
              _questions[to] = question;
            });
            await _persistShortcuts(orderOnly: true);
          },
        ),
      ),
    );
    if (mounted && picked != null) _sendQuestion(picked);
  }

  Future<void> _confirmHistoryClear() async {
    final session = widget._session;
    final scope = session.scope;
    if (!session.canClearHistory || scope == null) return;
    final generation = session.config?['historyGeneration'] as int? ?? 0;
    final title = context.lang.familyChatClearMyHistoryTitle;
    var saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: Text(dialogContext.lang.familyChatClearHistoryDialogContent),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.lang.commonCancel),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        await session.clearHistory(scope, generation);
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                this.context.lang.familyChatClearHistoryRetry,
                              ),
                            ),
                          );
                        }
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
              child: Text(dialogContext.lang.familyChatClearAction),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _options() => _showChatForm<void>(
    context,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChatFormHeader(
                title: context.lang.settingsTitle,
                icon: Icons.tune_rounded,
              ),
              const SizedBox(height: 8),
              const FamilyChatSettingsSection(showAccount: false),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(context.lang.familyChatClearMyHistoryTitle),
                enabled: widget._session.canClearHistory,
                onTap: widget._session.canClearHistory
                    ? () {
                        Navigator.of(context).pop();
                        unawaited(_confirmHistoryClear());
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    final loadingHistory = widget._session.isLoadingHistory(_recipient);
    if (messages.isNotEmpty && _positionedTargets.add(_recipient)) {
      _jumpToLatest();
    }
    final last = messages.lastOrNull?.id;
    if (last != _lastRenderedMessage &&
        !_initialScrollPending &&
        _scroll.hasClients &&
        _scroll.position.extentBefore < 60) {
      _toBottom();
    }
    _lastRenderedMessage = last;
    _scheduleRead();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final chrome = dark
        ? colors.surfaceContainer
        : colors.surfaceContainerLowest;
    final accent = dark ? colors.primary : colors.onPrimaryContainer;
    final divider = BorderSide(color: colors.outlineVariant);
    final composerBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: colors.outline),
    );
    final recipients = _recipients;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: chrome,
        systemOverlayStyle: theme.appBarTheme.systemOverlayStyle?.copyWith(
          systemNavigationBarColor: chrome,
          systemNavigationBarContrastEnforced: false,
        ),
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        titleSpacing: 0,
        toolbarHeight: 66,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: divider.color),
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final visibleCount = math.min(recipients.length, 3);
            final stripWidth = math.min(
              visibleCount * 62.0,
              constraints.maxWidth * 0.66,
            );
            final cellWidth = visibleCount == 0
                ? 0.0
                : stripWidth / visibleCount;
            return Row(
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.lang.familyChatNavTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget._session.error != null)
                        Text(
                          context.lang.familyChatOfflineQueued,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: stripWidth,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (index, recipient) in recipients.indexed)
                          SizedBox(
                            width: cellWidth,
                            child: _ConversationAvatar(
                              key: ValueKey('chat-target-$recipient'),
                              colorIndex: index,
                              name: _recipientName(
                                recipient,
                              ).trim().split(RegExp(r'\s+')).first,
                              selected: _recipient == recipient,
                              family: recipient == 'family',
                              hasUnread:
                                  widget._session.hasUnreadIn(recipient) ==
                                  true,
                              photoUrl:
                                  widget._session.members
                                          .where(
                                            (member) =>
                                                member['uid'] == recipient,
                                          )
                                          .firstOrNull?['photoUrl']
                                      as String?,
                              onTap: () => setState(() {
                                _draftTimer?.cancel();
                                unawaited(
                                  _persistDraft(_recipient, _input.text),
                                );
                                _recipient = recipient;
                                _jumpToLatest();
                                _draftTimer?.cancel();
                                _input.text = widget._session.draft(recipient);
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: context.lang.familyChatConversationOptionsTooltip,
            icon: const Icon(Icons.more_vert_rounded),
            color: accent,
            onPressed: _options,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget._session.historyClearPending ||
                widget._session.historyClearConflict)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  widget._session.historyClearPending
                      ? context.lang.familyChatHistoryClearPendingBanner
                      : context.lang.familyChatHistoryClearConflictBanner,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (widget._session.shortcutPending)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      widget._session.shortcutConflict
                          ? context.lang.familyChatShortcutConflict
                          : context.lang.familyChatShortcutPending,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (widget._session.shortcutConflict)
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: () async {
                              await widget._session.resolveShortcutConflict(
                                keepMine: false,
                              );
                              if (mounted) setState(_loadShortcuts);
                            },
                            child: Text(
                              context.lang.familyChatLoadSavedShortcuts,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await widget._session.resolveShortcutConflict(
                                keepMine: true,
                              );
                              if (mounted) setState(_loadShortcuts);
                            },
                            child: Text(context.lang.familyChatKeepMyShortcuts),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: accent),
                  icon: const Icon(Icons.history, size: 18),
                  label: Text(context.lang.familyChatOlderMessages),
                  onPressed: () async {
                    try {
                      await widget._session.loadHistory(_recipient);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.lang.familyChatLoadHistoryFailed,
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                if (widget._session.showingOlder(_recipient))
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: accent),
                    child: Text(context.lang.familyChatLatestMessages),
                    onPressed: () async {
                      try {
                        await widget._session.loadHistory(
                          _recipient,
                          latest: true,
                        );
                        if (mounted) _jumpToLatest();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.lang.familyChatLoadHistoryFailed,
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
            if (messages.isEmpty && loadingHistory)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(context.lang.familyChatLoadingMessages),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  key: _messageViewport,
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  itemCount: messages.length,
                  itemBuilder: (context, itemIndex) {
                    final index = messages.length - 1 - itemIndex;
                    final message = messages[index];
                    final previous = index == 0 ? null : messages[index - 1];
                    final newDay =
                        previous == null ||
                        !DateUtils.isSameDay(
                          previous.createdAt,
                          message.createdAt,
                        );
                    final newGroup =
                        newDay ||
                        previous.mine != message.mine ||
                        previous.sender != message.sender;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (newDay)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 14),
                            child: Row(
                              children: [
                                Expanded(child: Divider(color: divider.color)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    DateUtils.isSameDay(
                                          message.createdAt,
                                          DateTime.now(),
                                        )
                                        ? context.lang.familyChatToday
                                        : DateFormat(
                                            'dd.MM.yyyy',
                                          ).format(message.createdAt),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                                Expanded(child: Divider(color: divider.color)),
                              ],
                            ),
                          ),
                        KeyedSubtree(
                          key: message.id == null
                              ? null
                              : _messageKeys.putIfAbsent(
                                  message.id!,
                                  GlobalKey.new,
                                ),
                          child: _bubble(message, startsGroup: newGroup),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: chrome,
                border: Border(top: divider),
              ),
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ...[
                      GestureDetector(
                        onLongPress: !widget._session.serverVerified
                            ? null
                            : widget.isCaregiver
                            ? _quickQuestions
                            : _quickReplyMenu,
                        child: IconButton(
                          tooltip: widget.isCaregiver
                              ? context.lang.familyChatQuickQuestionTooltip
                              : context.lang.familyChatQuickReplyTooltip,
                          onPressed: !widget._session.serverVerified
                              ? null
                              : widget.isCaregiver
                              ? _quickQuestions
                              : _quickReplyMenu,
                          style: IconButton.styleFrom(
                            foregroundColor: accent,
                            minimumSize: const Size(36, 40),
                            padding: const EdgeInsets.all(6),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.bolt_rounded, size: 22),
                        ),
                      ),
                      const SizedBox(width: 2),
                      if (widget.isCaregiver && widget.showTreatmentAction) ...[
                        IconButton(
                          tooltip:
                              context.lang.familyChatSendLowTreatmentTooltip,
                          onPressed: !widget._session.serverVerified
                              ? null
                              : _composeLowTreatment,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(36, 40),
                            padding: const EdgeInsets.all(6),
                            foregroundColor: accent,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.cookie_outlined, size: 22),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 500,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          isDense: true,
                          counterText: '',
                          hintText: widget.isCaregiver
                              ? context.lang.familyChatComposerHintCaregiver
                              : context.lang.familyChatComposerHintChild,
                          filled: true,
                          fillColor: colors.surface,
                          border: composerBorder,
                          enabledBorder: composerBorder,
                          focusedBorder: composerBorder.copyWith(
                            borderSide: BorderSide(color: accent, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.isCaregiver)
                                IconButton(
                                  tooltip: context
                                      .lang
                                      .familyChatSendQuestionTooltip,
                                  onPressed:
                                      _sendingComposer ||
                                          !widget._session.canQueueComposer
                                      ? null
                                      : () => _sendComposer(question: true),
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(40, 40),
                                    padding: const EdgeInsets.all(8),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: Icon(
                                    Icons.help_outline_rounded,
                                    color: accent,
                                    size: 20,
                                  ),
                                ),
                              IconButton(
                                tooltip: _input.text.trim().isEmpty
                                    ? context.lang.familyChatSendOkTooltip
                                    : context.lang.familyChatSendMessageTooltip,
                                onPressed:
                                    _sendingComposer ||
                                        (!widget._session.canQueueComposer)
                                    ? null
                                    : _sendComposer,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(40, 40),
                                  padding: const EdgeInsets.all(8),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Icon(
                                  _input.text.trim().isEmpty
                                      ? Icons.thumb_up_alt_outlined
                                      : Icons.send_rounded,
                                  color: accent,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageReceipt(_Message message) {
    final time = _receiptTime(message.createdAt);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final receipts = message.groupReceipts;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(time, style: TextStyle(fontSize: 11, color: muted)),
        if (message.mine && receipts != null) ...[
          const SizedBox(width: 4),
          _groupReceiptIndicator(message, receipts, muted),
        ] else if (message.mine) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: _deliveryLabel(message.delivery, context.lang),
            child: Icon(
              switch (message.delivery) {
                _DeliveryState.pending => Icons.schedule_rounded,
                _DeliveryState.sent => Icons.done_rounded,
                _DeliveryState.delivered ||
                _DeliveryState.read => Icons.done_all_rounded,
                _DeliveryState.failed => Icons.error_outline_rounded,
              },
              size: 15,
              color: message.delivery == _DeliveryState.read
                  ? _accent
                  : message.delivery == _DeliveryState.failed
                  ? Theme.of(context).colorScheme.error
                  : muted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _groupReceiptIndicator(
    _Message message,
    List<_RecipientReceipt> receipts,
    Color muted,
  ) {
    final read = receipts
        .where((receipt) => receipt.state == _DeliveryState.read)
        .length;
    final allRead = receipts.isNotEmpty && read == receipts.length;
    final allDelivered = receipts.every(
      (receipt) =>
          receipt.state == _DeliveryState.read ||
          receipt.state == _DeliveryState.delivered,
    );
    final failed = receipts.any(
      (receipt) => receipt.state == _DeliveryState.failed,
    );
    final waiting = receipts.every(
      (receipt) => receipt.state == _DeliveryState.pending,
    );
    final color = allRead
        ? _accent
        : failed
        ? Theme.of(context).colorScheme.error
        : muted;
    return Tooltip(
      message: context.lang.familyChatGroupReceiptsTooltip,
      child: InkWell(
        onTap: () => _showGroupReceipts(message),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                allDelivered
                    ? Icons.done_all_rounded
                    : failed
                    ? Icons.error_outline_rounded
                    : waiting
                    ? Icons.schedule_rounded
                    : Icons.done_rounded,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 3),
              Text(
                '$read/${receipts.length}',
                key: const ValueKey('group-read-count'),
                style: TextStyle(fontSize: 10, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGroupReceipts(_Message message) async {
    final receipts = message.groupReceipts!;
    await _showChatForm<void>(
      context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChatFormHeader(
                title: context.lang.familyChatGroupReceiptsTitle,
                icon: Icons.done_all,
                subtitle: context.lang.familyChatGroupReceiptsSubtitle,
              ),
              Text(
                context.lang.familyChatGroupReadCount(
                  receipts
                      .where((receipt) => receipt.state == _DeliveryState.read)
                      .length,
                  receipts.length,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final receipt in receipts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: _accent.withValues(alpha: .12),
                    foregroundColor: _accent,
                    child: Text(receipt.name.substring(0, 1)),
                  ),
                  title: Row(
                    children: [
                      Text(receipt.name),
                      if (receipt.isChild)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            context.lang.familyChatChildRoleTag,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${_deliveryLabel(receipt.state, context.lang)}${receipt.readAt == null ? '' : ' · ${_receiptTime(receipt.readAt!)}'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubble(_Message message, {required bool startsGroup}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final fill = message.mine
        ? Color.alphaBlend(
            colors.primary.withValues(alpha: dark ? .22 : .17),
            colors.surface,
          )
        : dark
        ? colors.surfaceContainer
        : Color.alphaBlend(
            colors.onSurface.withValues(alpha: .075),
            colors.surface,
          );
    final groupReceipts = message.groupReceipts;
    final failed = groupReceipts != null
        ? groupReceipts.any((receipt) => receipt.state == _DeliveryState.failed)
        : message.delivery == _DeliveryState.failed;
    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: EdgeInsets.only(top: startsGroup ? 10 : 0, bottom: 5),
          child: Column(
            crossAxisAlignment: message.mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (startsGroup && !message.mine && message.sender.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 8,
                    bottom: 4,
                  ),
                  child: Text(
                    message.sender,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              IntrinsicWidth(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadiusDirectional.only(
                      topStart: const Radius.circular(17),
                      topEnd: const Radius.circular(17),
                      bottomStart: Radius.circular(message.mine ? 17 : 6),
                      bottomEnd: Radius.circular(message.mine ? 6 : 17),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.lowTreatment != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.restaurant_rounded,
                              color: _accent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.lang.familyChatLowTreatmentLabel,
                              style: const TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (message.selectedReply != null) ...[
                        Text(
                          message.selectedReply!
                              ? context.lang.familyChatSelectedReply
                              : context.lang.familyChatReply,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (message.replyContext case final quote?) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              8,
                              4,
                              8,
                              4,
                            ),
                            decoration: BoxDecoration(
                              border: BorderDirectional(
                                start: BorderSide(color: _accent, width: 2),
                              ),
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: .06,
                              ),
                            ),
                            child: Text(
                              '${_receiptTime(quote.sentAt)} · '
                              '${familyTreatmentSnapshotText(quote.treatment, context.lang, compact: true) ?? quote.text}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.isQuestion ||
                              message.selectedReply != null) ...[
                            Icon(
                              message.isQuestion
                                  ? Icons.help_outline_rounded
                                  : message.treatmentReplyIcon ??
                                        Icons.check_circle_rounded,
                              size: 18,
                              color: _accent,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              familyTreatmentSnapshotText(
                                    message.treatmentSnapshot,
                                    context.lang,
                                  ) ??
                                  _answerLabel(
                                    message,
                                    message.text,
                                    context.lang,
                                  ),
                              style: const TextStyle(fontSize: 16, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                      if (message.lowTreatment != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _treatmentStatus(message, context.lang) ??
                              context.lang.familyChatValidUntil(
                                _receiptTime(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    message.lowTreatment!.validUntil!,
                                  ),
                                ),
                              ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (message.answers.isNotEmpty &&
                          (message.lowTreatment == null
                              ? message.reply == null
                              : !widget.isCaregiver && !message.mine)) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final answer in message.answers)
                              if (message.mine || widget.isCaregiver)
                                Chip(
                                  label: Text(
                                    _answerLabel(message, answer, context.lang),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: _accent.withValues(
                                    alpha: .08,
                                  ),
                                  side: BorderSide.none,
                                )
                              else
                                OutlinedButton(
                                  onPressed:
                                      _canReply(message) &&
                                          (message.lowTreatment == null ||
                                              answer != _treatmentAteAnswer ||
                                              widget._session.serverVerified) &&
                                          (message.lowTreatment == null ||
                                              widget.confirmTreatment != null)
                                      ? () => _reply(message, answer)
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    side: BorderSide(
                                      color: _accent.withValues(alpha: .35),
                                    ),
                                  ),
                                  child: Text(
                                    answer == _treatmentAteAnswer &&
                                            message.lowTreatment != null &&
                                            _treatmentResults.containsKey(
                                              message.id,
                                            ) &&
                                            !_treatmentDone(message)
                                        ? context.lang.familyChatAteRetry(
                                            _quantityLabel(
                                              _treatmentQuantities[message
                                                      .id] ??
                                                  message
                                                      .lowTreatment!
                                                      .quantity,
                                            ),
                                            _unitLabel(
                                              message.lowTreatment!.unit,
                                              context.lang,
                                            ),
                                          )
                                        : _answerLabel(
                                            message,
                                            answer,
                                            context.lang,
                                          ),
                                  ),
                                ),
                          ],
                        ),
                      ],
                      if (!widget.isCaregiver &&
                          !message.mine &&
                          message.lowTreatment != null &&
                          widget.confirmTreatmentQuantity != null &&
                          !_treatmentDone(message)) ...[
                        TextButton(
                          onPressed:
                              _canReply(message) &&
                                  widget._session.serverVerified &&
                                  !_treatmentResults.containsKey(message.id) &&
                                  (widget.loadTreatmentResult == null ||
                                      _treatmentHydrated.contains(message.id))
                              ? () => _chooseConsumedQuantity(message)
                              : null,
                          child: Text(
                            context.lang.familyChatAteDifferentAmount,
                          ),
                        ),
                        if (_treatmentResults.containsKey(message.id))
                          Text(
                            context.lang.familyChatQuantityEstablished(
                              _quantityLabel(
                                _treatmentQuantities[message.id] ??
                                    message.lowTreatment!.quantity,
                              ),
                              _unitLabel(
                                message.lowTreatment!.unit,
                                context.lang,
                              ),
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                      const SizedBox(height: 3),
                      _messageReceipt(message),
                      if (message.mine && message.sendOutcomeUnknown) ...[
                        Text(context.lang.familyChatSendConfirmFailed),
                        TextButton.icon(
                          onPressed: widget._session.serverVerified
                              ? () async {
                                  try {
                                    await widget._session.verifyOutcome(
                                      _recipient,
                                      message.id!,
                                    );
                                  } catch (_) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context
                                                .lang
                                                .familyChatCheckStatusFailed,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.refresh, size: 14),
                          label: Text(context.lang.familyChatCheckStatus),
                        ),
                      ],
                      if (message.mine && message.redactedOutcome)
                        TextButton(
                          onPressed: widget._session.serverVerified
                              ? () async {
                                  await widget._session.discardOutcome(
                                    _recipient,
                                    message.id!,
                                  );
                                }
                              : null,
                          child: Text(
                            context.lang.familyChatDiscardLocalStatus,
                          ),
                        ),
                      if (message.mine && failed && !message.sendOutcomeUnknown)
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              await widget._session.retry(
                                _recipient,
                                message.id!,
                              );
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.lang.familyChatRetrySendFailed,
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.refresh, size: 14),
                          label: Text(context.lang.familyChatRetrySend),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionWheel extends StatefulWidget {
  const _QuestionWheel({
    required this.questions,
    required this.recipient,
    this.isReply = false,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
  });
  final List<_Question> questions;
  final String recipient;
  final bool isReply;
  final Future<void> Function() onAdd;
  final Future<void> Function(_Question) onEdit;
  final Future<void> Function(_Question) onDelete;
  final Future<void> Function(int, int) onMove;
  @override
  State<_QuestionWheel> createState() => _QuestionWheelState();
}

class _QuestionWheelState extends State<_QuestionWheel> {
  final _canvas = GlobalKey();
  _Question? _selected;
  int? _source;
  int? _target;
  Offset? _start;
  Offset? _pointer;
  bool _dragging = false;
  bool _busy = false;
  List<_Question> get questions => widget.questions;

  Offset _position(int index, double diameter) {
    final angle = -math.pi / 2 + index * 2 * math.pi / questions.length;
    return Offset(diameter / 2, diameter / 2) +
        Offset(math.cos(angle), math.sin(angle)) * diameter * .35;
  }

  void _move(LongPressMoveUpdateDetails details, double diameter) {
    if (_start == null || (details.globalPosition - _start!).distance < 18) {
      return;
    }
    final box = _canvas.currentContext!.findRenderObject()! as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    var nearest = _source!;
    var distance = double.infinity;
    for (var i = 0; i < questions.length; i++) {
      final candidate = (local - _position(i, diameter)).distance;
      if (candidate < distance) {
        distance = candidate;
        nearest = i;
      }
    }
    setState(() {
      _dragging = true;
      _pointer = local;
      _target = distance < 64 ? nearest : null;
    });
  }

  Future<void> _finishDrag() async {
    if (_busy) return;
    final move = _dragging && _target != null && _target != _source;
    final source = _source, target = _target;
    setState(() {
      if (_dragging) _selected = null;
      _dragging = false;
      _source = null;
      _target = null;
      _pointer = null;
      _busy = move;
    });
    try {
      if (move) await widget.onMove(source!, target!);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _action(bool delete) async {
    final selected = _selected;
    if (selected == null || _busy) return;
    setState(() {
      _selected = null;
      _busy = true;
    });
    try {
      if (delete) {
        await widget.onDelete(selected);
      } else {
        await widget.onEdit(selected);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addLabel = widget.isReply
        ? context.lang.familyChatAddReply
        : context.lang.familyChatAddQuestion;
    return Dialog(
      constraints: const BoxConstraints(maxWidth: 360),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: context.lang.familyChatCloseWheel,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final diameter = constraints.maxWidth;
                  final selectedIndex = _selected == null
                      ? -1
                      : questions.indexOf(_selected!);
                  final selectedPosition = selectedIndex < 0
                      ? Offset.zero
                      : _position(selectedIndex, diameter);
                  return GestureDetector(
                    onTap: () => setState(() => _selected = null),
                    child: Stack(
                      key: _canvas,
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 112,
                          height: 100,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF27313D),
                            ),
                            onPressed: questions.length >= 6
                                ? null
                                : () async {
                                    setState(() => _selected = null);
                                    await widget.onAdd();
                                    if (mounted) setState(() {});
                                  },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add, size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  addLabel,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        for (final (i, question) in questions.indexed)
                          Positioned(
                            left: _position(i, diameter).dx - 50,
                            top: _position(i, diameter).dy - 48,
                            width: 100,
                            height: 96,
                            child: Semantics(
                              button: true,
                              label: question.label,
                              customSemanticsActions: {
                                CustomSemanticsAction(
                                  label: context.lang.familyChatEditShortcut,
                                ): () {
                                  setState(() => _selected = question);
                                  _action(false);
                                },
                                CustomSemanticsAction(
                                  label: context.lang.familyChatDeleteShortcut,
                                ): () {
                                  setState(() => _selected = question);
                                  _action(true);
                                },
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _busy
                                    ? null
                                    : () => Navigator.pop(context, question),
                                onLongPressStart: _busy
                                    ? null
                                    : (details) => setState(() {
                                        _selected = question;
                                        _source = i;
                                        _target = null;
                                        _start = details.globalPosition;
                                        _dragging = false;
                                      }),
                                onLongPressMoveUpdate: (details) =>
                                    _move(details, diameter),
                                onLongPressEnd: (_) => _finishDrag(),
                                onLongPressCancel: () => setState(() {
                                  _selected = null;
                                  _dragging = false;
                                  _source = null;
                                  _target = null;
                                  _pointer = null;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: _dragging && _target == i
                                          ? _accent
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Opacity(
                                    opacity: _dragging && _source == i
                                        ? .25
                                        : 1,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _ShortcutIcon(
                                          question: question,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          question.label,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.2,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_dragging && _pointer != null)
                          Positioned(
                            left: _pointer!.dx - 20,
                            top: _pointer!.dy - 20,
                            child: IgnorePointer(
                              child: _ShortcutIcon(
                                question: _selected!,
                                size: 40,
                              ),
                            ),
                          ),
                        if (_selected != null && !_dragging)
                          Positioned(
                            left: (selectedPosition.dx - 124).clamp(
                              0.0,
                              math.max(0.0, diameter - 248),
                            ),
                            top: (selectedPosition.dy + 38).clamp(
                              0.0,
                              math.max(0.0, diameter - 56),
                            ),
                            width: math.min(248, diameter),
                            child: Material(
                              elevation: 3,
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(18),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => _action(false),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        context.lang.familyChatEditShortcut,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => _action(true),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                      ),
                                      label: Text(
                                        context.lang.familyChatDeleteShortcut,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.lang.familyChatWheelInstructions,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (questions.length >= 6)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.lang.familyChatWheelLimit,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutIcon extends StatelessWidget {
  const _ShortcutIcon({required this.question, this.size = 28});
  final _Question question;
  final double size;
  @override
  Widget build(BuildContext context) => Text(
    question.emoji,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: size,
      height: 1,
      fontFamilyFallback: const ['Noto Color Emoji'],
    ),
  );
}

class _ShortcutIconField extends StatelessWidget {
  const _ShortcutIconField({required this.question, required this.onChanged});
  final _Question question;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: _ShortcutIcon(question: question, size: 18),
    label: Text(context.lang.familyChatPickEmoji),
    onPressed: () async {
      final emoji = await _showChatForm<String>(
        context,
        builder: (_) => ShortcutEmojiPicker(selected: question.emoji),
      );
      if (emoji != null) onChanged(emoji);
    },
  );
}

class _QuickReplyEditor extends StatefulWidget {
  const _QuickReplyEditor({this.initial});
  final _Question? initial;
  @override
  State<_QuickReplyEditor> createState() => _QuickReplyEditorState();
}

class _QuickReplyEditorState extends State<_QuickReplyEditor> {
  late final _text = TextEditingController(text: widget.initial?.text ?? '');
  late final _label = TextEditingController(
    text: widget.initial?.label == widget.initial?.text
        ? ''
        : widget.initial?.label ?? '',
  );
  late String _emoji = widget.initial?.emoji ?? '💬';
  @override
  void dispose() {
    _text.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      0,
      16,
      MediaQuery.viewInsetsOf(context).bottom + 16,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChatFormHeader(
            title: widget.initial == null
                ? context.lang.familyChatNewReplyTitle
                : context.lang.familyChatEditReplyTitle,
            icon: Icons.chat_bubble_outline,
            subtitle: context.lang.familyChatReplyEditorSubtitle,
          ),
          _ShortcutIconField(
            question: _Question('', '', const [], _emoji),
            onChanged: (emoji) => setState(() => _emoji = emoji),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _label,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: context.lang.familyChatShortcutLabelOptional,
            ),
          ),
          TextField(
            controller: _text,
            maxLength: 80,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.lang.familyChatReplyContentLabel,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final text = _text.text.trim();
              if (text.isEmpty) return;
              final label = _label.text.trim();
              Navigator.pop(
                context,
                _Question(
                  label.isEmpty ? text.characters.take(40).toString() : label,
                  text,
                  const [],
                  _emoji,
                ),
              );
            },
            child: Text(context.lang.familyChatSaveReply),
          ),
        ],
      ),
    ),
  );
}

class _ConsumedQuantityEditor extends StatefulWidget {
  const _ConsumedQuantityEditor({required this.request});
  final _LowTreatmentRequest request;
  @override
  State<_ConsumedQuantityEditor> createState() =>
      _ConsumedQuantityEditorState();
}

class _ConsumedQuantityEditorState extends State<_ConsumedQuantityEditor> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.request.quantity.toString(),
  );
  double? get _quantity =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.'));
  double? get _nutrition {
    final quantity = _quantity;
    final source = widget.request;
    if (quantity == null ||
        !quantity.isFinite ||
        quantity <= 0 ||
        quantity > 10000) {
      return null;
    }
    final mass = source.gramsPerUnit == null
        ? null
        : quantity * source.gramsPerUnit!;
    if (mass != null && (!mass.isFinite || mass < .001 || mass > 10000)) {
      return null;
    }
    final raw =
        quantity *
        (source.sourceCarbsPerUnit ?? source.carbs / source.quantity);
    if (!raw.isFinite || raw <= 0 || raw > 10000) return null;
    final nutrition = familyTreatmentNutritionCarbs(raw);
    return nutrition >= .5 && nutrition <= 10000 ? nutrition : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = _nutrition;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChatFormHeader(
                title: context.lang.familyChatConsumedQuantityTitle,
                icon: Icons.cookie_outlined,
                subtitle: widget.request.product,
              ),
              TextFormField(
                key: const ValueKey('consumed-quantity'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.lang.familyChatActuallyConsumedLabel(
                    _unitLabel(widget.request.unit, context.lang),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: (_) => _nutrition == null
                    ? context.lang.familyChatInvalidConsumedQuantity
                    : null,
              ),
              const SizedBox(height: 10),
              if (nutrition != null)
                Text(
                  context.lang.familyChatConsumedNutritionSummary(
                    nutrition.toString().replaceAll('.', ','),
                    familyTreatmentRecordedCarbs(nutrition),
                  ),
                ),
              const SizedBox(height: 10),
              Text(context.lang.familyChatConfirmAfterEatingNote),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(context, _quantity);
                  }
                },
                child: Text(context.lang.familyChatAteSaveThisAmount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the same request form from a conversation or from the dashboard.
Future<String?> showFamilyLowTreatmentComposer(
  BuildContext context, {
  required FamilyChatSession session,
  required String target,
  required List<FamilyChatFoodChoice> foods,
  Future<void> Function()? onEdit,
  Future<FamilyChatFoodChoice?> Function(BuildContext)? pickIngredient,
}) async {
  final scope = session.scope;
  final request = await _showChatForm<_LowTreatmentRequest>(
    context,
    builder: (_) => _LowTreatmentRequestEditor(
      foods: foods,
      onEdit: onEdit,
      pickIngredient: pickIngredient,
    ),
  );
  if (!context.mounted ||
      request == null ||
      !session.serverVerified ||
      !session.isCurrentAccount() ||
      scope == null ||
      session.scope != scope ||
      !session.targets.contains(target)) {
    return null;
  }
  try {
    String? id;
    await session.send(
      target,
      request.textFor(context.lang),
      kind: 'lowTreatment',
      treatment: request.snapshot(session.serverNow),
      onQueued: (queued) => id = queued,
    );
    return context.mounted &&
            session.scope == scope &&
            session.isCurrentAccount()
        ? id
        : null;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.familyChatEnqueueFailed)),
      );
    }
    return null;
  }
}

class _LowTreatmentRequestEditor extends StatefulWidget {
  const _LowTreatmentRequestEditor({
    required this.foods,
    this.pickIngredient,
    this.onEdit,
  });
  final List<FamilyChatFoodChoice> foods;
  final Future<FamilyChatFoodChoice?> Function(BuildContext)? pickIngredient;
  final Future<void> Function()? onEdit;
  @override
  State<_LowTreatmentRequestEditor> createState() =>
      _LowTreatmentRequestEditorState();
}

class _LowTreatmentRequestEditorState
    extends State<_LowTreatmentRequestEditor> {
  final _form = GlobalKey<FormState>();
  final _product = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _pieceWeight = TextEditingController();
  final _carbs = TextEditingController();
  FamilyChatFoodChoice? _selected;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    final first = widget.foods
        .where((food) => food.quickShortcut && food.carbsPerUnit > 0)
        .firstOrNull;
    if (first != null) _applyFood(first);
  }

  bool get _needsPieceWeight => _selected?.unit == 'g';

  double? get _gramsPerPiece => _needsPieceWeight
      ? double.tryParse(_pieceWeight.text.trim().replaceAll(',', '.'))
      : _selected?.gramsPerUnit;

  double? get _carbsPerPiece {
    final selected = _selected;
    if (selected == null) return null;
    final weight = _gramsPerPiece;
    return _needsPieceWeight
        ? weight == null || !weight.isFinite || weight <= 0
              ? null
              : weight * selected.carbsPerUnit
        : selected.carbsPerUnit;
  }

  void _select(FamilyChatFoodChoice food) {
    if (!food.carbsPerUnit.isFinite || food.carbsPerUnit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.familyChatFoodCarbsMissing)),
      );
      return;
    }
    setState(() => _applyFood(food));
  }

  void _applyFood(FamilyChatFoodChoice food) {
    _selected = food;
    _product.text = food.name;
    _quantity.text = _needsPieceWeight
        ? '1'
        : food.initialAmount?.toString() ?? '';
    _pieceWeight.text = _needsPieceWeight
        ? food.gramsPerUnit?.toString() ?? ''
        : '';
    _recalculate();
  }

  void _clearFood() => setState(() {
    _selected = null;
    _product.clear();
    _quantity.text = '1';
    _pieceWeight.clear();
    _carbs.clear();
  });

  void _recalculate() {
    if (_selected == null) return;
    final quantity = double.tryParse(
      _quantity.text.trim().replaceAll(',', '.'),
    );
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      _carbs.clear();
      return;
    }
    final perPiece = _carbsPerPiece;
    final exact = perPiece == null ? null : quantity * perPiece;
    if (exact == null || !exact.isFinite || exact <= 0 || exact > 10000) {
      _carbs.clear();
      return;
    }
    final nutrition = familyTreatmentNutritionCarbs(exact);
    final displayed = nutrition
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0{1,4}$'), '');
    _carbs.text = displayed.replaceAll('.', ',');
  }

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final food = await widget.pickIngredient!(context);
      if (mounted && food != null) _select(food);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.familyChatPickIngredientFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  double? get _grams =>
      double.tryParse(_carbs.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _product.dispose();
    _quantity.dispose();
    _pieceWeight.dispose();
    _carbs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      0,
      16,
      MediaQuery.viewInsetsOf(context).bottom + 16,
    ),
    child: SafeArea(
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChatFormHeader(
                title: context.lang.familyChatLowTreatmentTitle,
                icon: Icons.cookie_outlined,
                subtitle: context.lang.familyChatLowTreatmentEditorSubtitle,
              ),
              if (widget.foods.isNotEmpty || widget.pickIngredient != null) ...[
                const SizedBox(height: 10),
                QuickLowTreatmentSelection(
                  enabled: !_picking,
                  actionLabel: _picking
                      ? context.lang.familyChatOpeningPicker
                      : context.lang.familyChatPickIngredientFromList,
                  actionIcon: Icons.search,
                  onAction: widget.pickIngredient == null ? null : _pick,
                  onEdit: widget.onEdit,
                  choices: [
                    for (final food in widget.foods)
                      QuickLowTreatmentTile(
                        name: food.name,
                        iconAssetPath: food.iconAssetPath,
                        selected: identical(food, _selected),
                        onTap: _picking ? null : () => _select(food),
                      ),
                  ],
                  selected: _selected?.quickShortcut != true
                      ? null
                      : QuickLowTreatmentAmount(
                          name: _selected!.name,
                          iconAssetPath: _selected!.iconAssetPath,
                          unit: _unitLabel(_selected!.unit, context.lang),
                          quantity: double.parse(_quantity.text),
                          onClear: _clearFood,
                          onChanged: (value) => setState(() {
                            _quantity.text = value.toString();
                            _recalculate();
                          }),
                        ),
                ),
              ],
              const SizedBox(height: 10),
              if (_selected?.quickShortcut != true)
                TextFormField(
                  controller: _product,
                  readOnly: _selected != null,
                  maxLength: 60,
                  decoration: InputDecoration(
                    labelText: context.lang.familyChatProductLabel,
                    hintText: context.lang.familyChatProductHint,
                    counterText: '',
                    suffixIcon: _selected == null
                        ? null
                        : IconButton(
                            tooltip: context
                                .lang
                                .familyChatTypeProductManuallyTooltip,
                            icon: const Icon(Icons.close),
                            onPressed: _clearFood,
                          ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.lang.familyChatProductRequired
                      : null,
                ),
              const SizedBox(height: 12),
              if (_needsPieceWeight) ...[
                TextFormField(
                  controller: _pieceWeight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.lang.familyChatPieceWeightGrams,
                  ),
                  onChanged: (_) => setState(_recalculate),
                  validator: (_) {
                    final weight = _gramsPerPiece;
                    final quantity = double.tryParse(
                      _quantity.text.replaceAll(',', '.'),
                    );
                    final total = weight == null || quantity == null
                        ? null
                        : weight * quantity;
                    return weight == null ||
                            !weight.isFinite ||
                            weight <= 0 ||
                            (total != null && (total < .001 || total > 10000))
                        ? context.lang.familyChatPositiveNumberRequired
                        : null;
                  },
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  if (_selected?.quickShortcut != true)
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        onChanged: (_) => setState(_recalculate),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _selected == null
                              ? context.lang.familyChatPortionCountLabel
                              : context.lang.familyChatQuantityWithUnitLabel(
                                  _unitLabel(
                                    _needsPieceWeight
                                        ? 'piece'
                                        : _selected!.unit,
                                    context.lang,
                                  ),
                                ),
                        ),
                        validator: (value) {
                          final count = double.tryParse(
                            (value?.trim() ?? '').replaceAll(',', '.'),
                          );
                          return count == null || !count.isFinite || count <= 0
                              ? context.lang.familyChatPositiveNumberRequired
                              : null;
                        },
                      ),
                    ),
                  if (_selected?.quickShortcut != true)
                    const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _carbs,
                      readOnly: _selected != null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.lang.familyChatCarbsLabel,
                        suffixText: 'g',
                      ),
                      validator: (_) {
                        final value = _grams;
                        if (value == null || !value.isFinite || value < .5) {
                          return context.lang.familyChatCarbsMinimumValidation;
                        }
                        if (value > 10000) {
                          return context.lang.familyChatCarbsLimitExceeded;
                        }
                        if (_selected == null &&
                            value != familyTreatmentNutritionCarbs(value)) {
                          return context.lang.familyChatCarbsMaxDecimals;
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_grams != null &&
                  _grams!.isFinite &&
                  _grams! >= .5 &&
                  _grams! <= 10000)
                Text(
                  context.lang.familyChatTreatmentRecordedNote(
                    familyTreatmentRecordedCarbs(_grams!),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              Text(
                context.lang.familyChatTreatmentValid30Minutes,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.send_outlined),
                label: Text(context.lang.familyChatSendTreatmentRequest),
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    _LowTreatmentRequest(
                      _product.text.trim(),
                      double.parse(_quantity.text.trim().replaceAll(',', '.')),
                      familyTreatmentNutritionCarbs(_grams!),
                      unit: _needsPieceWeight
                          ? 'piece'
                          : _selected?.unit ?? 'portion',
                      gramsPerUnit: _gramsPerPiece,
                      sourceCarbsPerUnit: _carbsPerPiece,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({
    super.key,
    required this.name,
    required this.colorIndex,
    required this.selected,
    required this.family,
    required this.hasUnread,
    required this.onTap,
    this.photoUrl,
  });

  final String name;
  final int colorIndex;
  final bool selected, family, hasUnread;
  final String? photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = theme.brightness == Brightness.dark
        ? colors.primary
        : colors.onPrimaryContainer;
    final (background, foreground) = family
        ? (colors.secondaryContainer, colors.onSecondaryContainer)
        : switch (colorIndex % 3) {
            0 => (colors.primaryContainer, colors.onPrimaryContainer),
            1 => (colors.tertiaryContainer, colors.onTertiaryContainer),
            _ => (colors.secondaryContainer, colors.onSecondaryContainer),
          };
    final url = Uri.tryParse(photoUrl ?? '');
    final image = !family && url?.scheme == 'https' && url!.host.isNotEmpty
        ? NetworkImage(url.toString())
        : null;
    return Semantics(
      button: true,
      selected: selected,
      label: hasUnread
          ? context.lang.familyChatUnreadMessagesSemantics(name)
          : name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Badge(
                    isLabelVisible: hasUnread,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: background,
                      foregroundColor: foreground,
                      foregroundImage: image,
                      onForegroundImageError: image == null ? null : (_, _) {},
                      child: family
                          ? const Icon(Icons.groups_rounded, size: 18)
                          : Text(
                              name.trim().isEmpty
                                  ? '?'
                                  : name.trim().characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected ? accent : colors.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor({
    this.initial,
    this.text = '',
    required this.sendAfterSave,
  });
  final _Question? initial;
  final String text;
  final bool sendAfterSave;
  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late String _emoji = widget.initial?.emoji ?? '💬';
  late final _label = TextEditingController(text: widget.initial?.label ?? '');
  late final _text = TextEditingController(
    text: widget.initial?.text ?? widget.text,
  );
  late final _answers = [
    for (final answer in widget.initial?.answers ?? <String>[])
      TextEditingController(text: answer),
  ];
  final _removedAnswers = <TextEditingController>[];
  @override
  void dispose() {
    _label.dispose();
    _text.dispose();
    for (final answer in [..._answers, ..._removedAnswers]) {
      answer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      0,
      16,
      MediaQuery.viewInsetsOf(context).bottom + 16,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChatFormHeader(
            title: widget.sendAfterSave
                ? context.lang.familyChatAskChildTitle
                : widget.initial == null
                ? context.lang.familyChatNewQuestionTitle
                : context.lang.familyChatEditQuestionTitle,
            icon: Icons.chat_bubble_outline,
            subtitle: widget.sendAfterSave
                ? context.lang.familyChatAskChildSubtitle
                : context.lang.familyChatSaveShortcutWheelSubtitle,
          ),
          const SizedBox(height: 12),
          if (!widget.sendAfterSave) ...[
            _ShortcutIconField(
              question: _Question('', '', const [], _emoji),
              onChanged: (emoji) => setState(() => _emoji = emoji),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _label,
              maxLength: 24,
              decoration: InputDecoration(
                labelText: context.lang.familyChatShortcutLabelOnWheel,
                hintText: context.lang.familyChatShortcutLabelHint,
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _text,
            maxLength: 160,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.lang.familyChatQuestionContentLabel,
              hintText: context.lang.familyChatQuestionContentHint,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.lang.familyChatProposedAnswersHeader,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton.filledTonal(
                tooltip: context.lang.familyChatAddAnswerTooltip,
                onPressed: _answers.length < _maxQuestionAnswers
                    ? () =>
                          setState(() => _answers.add(TextEditingController()))
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.lang.familyChatQuestionAnswerLimit,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _answers.length; i++)
            Padding(
              key: ValueKey(_answers[i]),
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _answers[i],
                maxLength: 28,
                decoration: InputDecoration(
                  labelText: context.lang.familyChatAnswerNumberedLabel(i + 1),
                  counterText: '',
                  suffixIcon: IconButton(
                    tooltip: context.lang.familyChatDeleteAnswerTooltip(i + 1),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(
                      () => _removedAnswers.add(_answers.removeAt(i)),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              final text = _text.text.trim();
              final answers = _answers
                  .map((c) => c.text.trim())
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList();
              if (answers.length > _maxQuestionAnswers) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.lang.familyChatQuestionAnswerLimit),
                  ),
                );
                return;
              }
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.lang.familyChatQuestionTextRequired),
                  ),
                );
                return;
              }
              Navigator.pop(
                context,
                _Question(
                  _label.text.trim().isEmpty
                      ? context.lang.familyChatMyQuestionDefaultLabel
                      : _label.text.trim(),
                  text,
                  answers,
                  _emoji,
                ),
              );
            },
            child: Text(
              widget.sendAfterSave
                  ? context.lang.familyChatSendQuestion
                  : context.lang.familyChatSaveQuestion,
            ),
          ),
        ],
      ),
    ),
  );
}
