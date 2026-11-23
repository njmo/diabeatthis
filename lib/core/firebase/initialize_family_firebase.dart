import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';
import 'firebase_app_check_provider.dart';

Future<void> initializeFamilyFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await activateFamilyAppCheck();
}
