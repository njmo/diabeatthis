import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/language.dart';
import 'family_pairing_code_dialog.dart';

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
  AppLifecycleState lifecycle = AppLifecycleState.resumed;
  bool returned = false;
  bool enteringCode = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scanner.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    lifecycle = state;
    if (state == AppLifecycleState.resumed && !enteringCode && !returned) {
      scanner.start();
    } else {
      scanner.stop();
    }
  }

  Future<void> enterCode() async {
    if (returned || enteringCode) return;
    enteringCode = true;
    try {
      try {
        await scanner.stop();
      } catch (_) {}
      if (!mounted) return;
      final code = await showFamilyPairingCodeDialog(context);
      if (!mounted) return;
      if (code != null) {
        returned = true;
        Navigator.of(context).pop('code:$code');
      }
    } finally {
      enteringCode = false;
      if (mounted && !returned && lifecycle == AppLifecycleState.resumed) {
        try {
          await scanner.start();
        } catch (_) {}
      }
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
    bottomNavigationBar: SafeArea(
      child: TextButton.icon(
        onPressed: enterCode,
        icon: const Icon(Icons.keyboard),
        label: Text(context.lang.familyEnterPairingCode),
      ),
    ),
    body: MobileScanner(
      controller: scanner,
      errorBuilder: (context, error) =>
          Center(child: Text(context.lang.familyCameraFailed)),
      onDetect: (capture) {
        final value = capture.barcodes.firstOrNull?.rawValue;
        if (!returned && !enteringCode && value != null) {
          returned = true;
          Navigator.of(context).pop(value);
        }
      },
    ),
  );
}
