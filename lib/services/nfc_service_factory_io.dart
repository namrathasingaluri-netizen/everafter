import 'dart:io';

import 'package:everafter/services/android_nfc_service.dart';
import 'package:everafter/services/nfc_configuration.dart';
import 'package:everafter/services/nfc_service.dart';
import 'package:everafter/services/ios_nfc_service.dart';
import 'package:everafter/services/pn532_nfc_service.dart';

NfcService createNfcService() {
  if (Platform.isAndroid) {
    return AndroidNfcService();
  }

  if (Platform.isIOS && nativeIosNfcEnabled) {
    return IosNfcService();
  }

  final environment = Platform.environment;
  final mode = environment['EVERAFTER_NFC_MODE']?.trim().toLowerCase();
  if (Platform.isLinux && mode == 'pn532') {
    final arguments =
        environment['EVERAFTER_NFC_ARGS']
            ?.trim()
            .split(RegExp(r'\s+'))
            .where((argument) => argument.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    return Pn532NfcService(
      executable: environment['EVERAFTER_NFC_COMMAND'] ?? 'nfc-poll',
      arguments: arguments,
    );
  }
  return DemoNfcService();
}
