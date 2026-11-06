import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/language.dart';

class FamilyQrScannerPage extends StatefulWidget {
  const FamilyQrScannerPage({super.key});
  @override
  State<FamilyQrScannerPage> createState() => FamilyQrScannerPageState();
}

class FamilyQrScannerPageState extends State<FamilyQrScannerPage>
    with WidgetsBindingObserver {
  late final scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    autoStart: false,
  );
  bool returned = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scanner.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      scanner.start();
    } else {
      scanner.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.lang.setupScanChildTitle)),
    body: MobileScanner(
      controller: scanner,
      errorBuilder: (context, error) =>
          Center(child: Text(context.lang.familyCameraFailed)),
      onDetect: (capture) {
        final value = capture.barcodes.firstOrNull?.rawValue;
        if (!returned && value != null) {
          returned = true;
          Navigator.of(context).pop(value);
        }
      },
    ),
  );
}
