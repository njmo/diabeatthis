import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../widgets/management_content.dart';

@RoutePage()
class ManagementPage extends StatelessWidget {
  const ManagementPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.lang.dashboardLibraryTab)),
    body: const ManagementContent(),
  );
}
