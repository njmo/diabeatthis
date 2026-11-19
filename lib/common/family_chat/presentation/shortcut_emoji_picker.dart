import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../../utils/normalize_search_text.dart';

const _recommended = [
  emoji.Emoji('🥪', 'Śniadanie | kanapka | jedzenie'),
  emoji.Emoji('💧', 'Woda | picie | pragnienie'),
  emoji.Emoji('🍎', 'Jabłko | owoc | jedzenie'),
  emoji.Emoji('🍬', 'Cukierek | cukier | dosłodzenie'),
  emoji.Emoji('🎒', 'Plecak | szkoła | lekcje'),
  emoji.Emoji('📚', 'Książki | szkoła | nauka'),
  emoji.Emoji('⏰', 'Budzik | przerwa | czas | później'),
  emoji.Emoji('🙂', 'Uśmiech | dobrze | samopoczucie'),
  emoji.Emoji('😟', 'Zmartwienie | źle | smutek'),
  emoji.Emoji('🤒', 'Choroba | gorączka | samopoczucie'),
  emoji.Emoji('📞', 'Telefon | zadzwoń | kontakt'),
  emoji.Emoji('🏠', 'Dom | wracam | rodzina'),
  emoji.Emoji('👍', 'Dobrze | okej | tak'),
  emoji.Emoji('❤️', 'Serce | miłość | kocham'),
  emoji.Emoji('👀', 'Oczy | patrzę | sprawdzam'),
  emoji.Emoji('✅', 'Gotowe | zrobione | potwierdzenie'),
  emoji.Emoji('🤔', 'Myślę | pytanie | zastanawiam się'),
  emoji.Emoji('🙋', 'Pomoc | pytanie | zgłaszam się'),
  emoji.Emoji('🚌', 'Autobus | szkoła | dojazd'),
  emoji.Emoji('🏃', 'Bieg | sport | aktywność'),
];

/// Picks a Unicode string only; never writes a shortcut or user preferences.
class ShortcutEmojiPicker extends StatefulWidget {
  const ShortcutEmojiPicker({super.key, required this.selected});
  final String selected;
  @override
  State<ShortcutEmojiPicker> createState() => _ShortcutEmojiPickerState();
}

class _ShortcutEmojiPickerState extends State<ShortcutEmojiPicker> {
  bool _expanded = false;
  bool _loading = false;
  bool _failed = false;
  List<emoji.CategoryEmoji> _all = const [];
  emoji.Category? _category;
  String _query = '';

  Future<void> _expand() async {
    setState(() {
      _expanded = true;
      _loading = true;
      _failed = false;
    });
    try {
      final all = await emoji.EmojiPickerUtils().filterUnsupported(
        emoji.defaultEmojiSet,
      );
      if (mounted) setState(() => _all = all);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        keyboard -
        MediaQuery.paddingOf(context).top;
    final available = _expanded
        ? _all
              .where(
                (group) => _category == null || group.category == _category,
              )
              .expand((group) => group.emoji)
        : _recommended;
    final aliases = {for (final item in _recommended) item.emoji: item.name};
    final query = normalizeSearchText(_query);
    final items = available.where((item) {
      if (_query.trim() == item.emoji) return true;
      final terms = normalizeSearchText(
        '${item.name} ${aliases[item.emoji] ?? ''}',
      );
      return query.split(RegExp(r'\s+')).every(terms.contains);
    }).toList();
    return SizedBox(
      height: math.min(availableHeight * .9, _expanded ? 540 : 380) + keyboard,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + keyboard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.lang.familyChatPickEmoji,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.lang.familyChatCloseEmojiPicker,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            if (_expanded) ...[
              TextField(
                decoration: InputDecoration(
                  hintText: context.lang.familyChatSearchEmojiHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(context.lang.familyChatEmojiCategoryAll),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                    ),
                    for (final group in _all)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            _categoryLabel(group.category, context.lang),
                          ),
                          selected: _category == group.category,
                          onSelected: (_) =>
                              setState(() => _category = group.category),
                        ),
                      ),
                  ],
                ),
              ),
            ] else
              Text(
                context.lang.familyChatEmojiRecommendedSubtitle,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _failed
                  ? Center(
                      child: TextButton(
                        onPressed: _expand,
                        child: Text(context.lang.commonRetry),
                      ),
                    )
                  : items.isEmpty
                  ? Center(child: Text(context.lang.familyChatEmojiNotFound))
                  : GridView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 56,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = item.emoji == widget.selected;
                        return Semantics(
                          label: item.name.split(' | ').first,
                          button: true,
                          selected: selected,
                          child: InkWell(
                            key: ValueKey('emoji-${item.emoji}'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context, item.emoji),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: selected
                                    ? colors.primary.withValues(alpha: .12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  item.emoji,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    height: 1,
                                    fontFamilyFallback: ['Noto Color Emoji'],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (!_expanded)
              TextButton.icon(
                onPressed: _expand,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: Text(context.lang.familyChatAllEmoji),
              ),
          ],
        ),
      ),
    );
  }
}

String _categoryLabel(emoji.Category category, AppLocalizations lang) =>
    switch (category) {
      emoji.Category.SMILEYS => lang.familyChatEmojiCategorySmileys,
      emoji.Category.ANIMALS => lang.familyChatEmojiCategoryAnimals,
      emoji.Category.FOODS => lang.familyChatEmojiCategoryFood,
      emoji.Category.ACTIVITIES => lang.familyChatEmojiCategoryActivities,
      emoji.Category.TRAVEL => lang.familyChatEmojiCategoryTravel,
      emoji.Category.OBJECTS => lang.familyChatEmojiCategoryObjects,
      emoji.Category.SYMBOLS => lang.familyChatEmojiCategorySymbols,
      emoji.Category.FLAGS => lang.familyChatEmojiCategoryFlags,
      _ => lang.familyChatEmojiCategoryRecent,
    };
