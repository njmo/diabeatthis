import 'package:flutter/foundation.dart';

bool get supportsFamilyChat =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
