import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'nightscout_source_key.dart';

/// A URL change rotates revision; returning to an old URL cannot revive its queue.
String nightscoutDeliveryKey(String url, String revision) => sha256
    .convert(utf8.encode('${nightscoutSourceKey(url)}\n$revision'))
    .toString();
