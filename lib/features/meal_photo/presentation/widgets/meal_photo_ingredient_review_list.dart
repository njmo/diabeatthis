import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/widgets/scroll_to_widget_after_layout.dart';
import '../../domain/models/meal_photo_review_item.dart';
import 'meal_photo_selection_origin.dart';

class MealPhotoIngredientReviewList extends HookWidget {
  const MealPhotoIngredientReviewList({
    super.key,
    required this.items,
    required this.builder,
  });
  final List<MealPhotoReviewItem> items;
  final Widget Function(MealPhotoReviewItem, VoidCallback) builder;
  @override
  Widget build(BuildContext context) {
    final active = useState<String?>(
      items.where((item) => !item.reviewed).firstOrNull?.proposal.id,
    );
    final shown = items.any((item) => item.proposal.id == active.value)
        ? active.value
        : items.where((item) => !item.reviewed).firstOrNull?.proposal.id;
    final itemKeys = useMemoized(() => <String, GlobalKey>{});
    for (final item in items) {
      itemKeys.putIfAbsent(item.proposal.id, GlobalKey.new);
    }
    final previousShown = useRef(shown);
    useEffect(() {
      final changed = previousShown.value != shown;
      previousShown.value = shown;
      if (!changed || shown == null) return null;
      return scrollToWidgetAfterLayout(itemKeys[shown]!);
    }, [shown]);
    return Column(
      children: items
          .map(
            (item) => item.proposal.id == shown
                ? KeyedSubtree(
                    key: itemKeys[item.proposal.id],
                    child: builder(item, () {
                      active.value = items
                          .where(
                            (other) =>
                                other.proposal.id != item.proposal.id &&
                                !other.reviewed,
                          )
                          .firstOrNull
                          ?.proposal
                          .id;
                    }),
                  )
                : ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.reviewed
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(item.displayName),
                    subtitle: MealPhotoSelectionOrigin(item: item),
                    trailing: Text(
                      '${item.weightGrams?.toStringAsFixed(0) ?? "—"} g',
                    ),
                    onTap: () => active.value = item.proposal.id,
                  ),
          )
          .toList(),
    );
  }
}
