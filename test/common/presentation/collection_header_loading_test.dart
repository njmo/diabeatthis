import 'package:diabeatthis/common/presentation/collections/models/collection_state.dart';
import 'package:diabeatthis/common/presentation/collections/views/collection_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'a header retains initial loading feedback without moving cached items on refresh',
    (tester) async {
      Future<void> render(CollectionState<String> state) => tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: CollectionListView<String>(
              state: state,
              header: const [Text('Upcoming sessions')],
              emptyLabel: 'No sessions',
              onRetry: () {},
              onLoadMore: () {},
              itemBuilder: (_, item) => Text(item),
            ),
          ),
        ),
      );
      await render(const CollectionState(items: [], loading: true));
      expect(find.text('Upcoming sessions'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await render(const CollectionState(items: ['Training']));
      final position = tester.getTopLeft(find.text('Training'));
      await render(const CollectionState(items: ['Training'], loading: true));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.getTopLeft(find.text('Training')), position);
    },
  );
}
