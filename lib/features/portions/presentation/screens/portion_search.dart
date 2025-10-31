import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../meals/data/providers/meal_provider.dart';
import '../../data/drafts/portion_draft.dart';
import '../../data/mappers/portion_draft_mapper.dart';
import '../../data/providers/portion_provider.dart';
import 'portion_form.dart';

class PortionSearch extends HookConsumerWidget {
  const PortionSearch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final portions = ref.watch(portionsByQueryProvider(query.value));
    return AlertDialog(
      content: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                StringFormField(
                  label: 'Nazwa',
                  value: '',
                  onChanged: (String asd) {},
                  builder: (context, controller) {
                    return TextFormField(
                      autofocus: true,
                      controller: controller,
                      onChanged: (value) {
                        query.value = value;
                      },
                      maxLength: 30,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter a title.';
                        } else if (value.length > 20) {
                          return 'Limit the title to 20 characters.';
                        } else {
                          return null;
                        }
                      },
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search),
                        labelText: 'Nazwa',
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                ),
                portions.when(
                  data: (data) {
                    return SingleChildScrollView(
                      child: ListView.builder(
                        itemBuilder: (context, index) {
                          if (data.isEmpty)
                            return Text('No data');
                          final portion = data[index];
                          return ListTile(
                            title: Text(portion.name),
                            subtitle: Text(portion.unitHint),
                            onTap: () {
                              Navigator.of(context).pop(portion.toSelection());
                            },
                          );
                        },
                        itemCount: data.length,
                        shrinkWrap: true,
                      ),
                    );
                  },
                  error: (error, stackTrace) => Text(error.toString()),
                  loading: () => CircularProgressIndicator(),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () { Navigator.of(context).pop(); } , child: Text('Cancel'))],
    );
  }
}
