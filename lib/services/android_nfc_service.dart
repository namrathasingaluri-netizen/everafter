import 'dart:async';

import 'package:everafter/services/nfc_service.dart';
import 'package:flutter/services.dart';

class AndroidNfcService implements NfcService {
  AndroidNfcService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.example.everafter/nfc';

  final MethodChannel _channel;
  final _controller = StreamController<String>.broadcast(sync: true);

  @override
  Stream<String> get detectedUids => _controller.stream;

  @override
  Future<String?> startScan() async {
    try {
      final uid = await _channel.invokeMethod<String>('scanMagnet');
      if (uid == null || uid.isEmpty) {
        return null;
      }
      if (!_controller.isClosed) {
        _controller.add(uid);
      }
      return uid;
    } on PlatformException catch (error) {
      throw NfcScanException(
        error.message ?? 'EverAfter could not scan this magnet.',
        wasCancelled: error.code == 'cancelled',
      );
    }
  }

  @override
  Future<void> scanDemo(String uid) async {
    if (!_controller.isClosed) {
      _controller.add(uid);
    }
  }

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}
