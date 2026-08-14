import 'dart:async';

import 'package:everafter/app.dart';
import 'package:everafter/services/android_nfc_service.dart';
import 'package:everafter/services/nfc_service.dart';
import 'package:everafter/services/nfc_service_provider.dart';
import 'package:everafter/state/museum_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _japanUid = '04:00:00:00:00:04';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Android NFC service normalizes a native scan into the UID stream',
    () async {
      const channel = MethodChannel('everafter.test/android-nfc');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'scanMagnet');
            return _japanUid;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final service = AndroidNfcService(channel: channel);
      addTearDown(service.dispose);
      final detectedUid = service.detectedUids.first;

      expect(await service.startScan(), _japanUid);
      expect(await detectedUid, _japanUid);
    },
  );

  testWidgets('Android NFC setup explains scanning and scan-to-open links', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const ProviderScope(child: EverAfterApp(showSplash: false)),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('android-nfc-setup')), findsOneWidget);
      expect(find.byKey(const ValueKey('scan-magnet')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('android-nfc-setup')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Scan magnets on Android'), findsOneWidget);
      expect(find.text('OPTIONAL · SCAN TO OPEN'), findsOneWidget);
      expect(find.text('everafter:///nfc/south-korea'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android Scan Magnet action opens and starts the linked trip', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final service = _FakeAndroidNfcService(_japanUid);
    addTearDown(service.dispose);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [nfcServiceProvider.overrideWithValue(service)],
          child: const EverAfterApp(showSplash: false),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('scan-magnet')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(service.scanCount, 1);
      expect(service.hadListenerWhenScanned, isTrue);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EverAfterApp)),
      );
      final museumState = container.read(museumControllerProvider);
      expect(
        <String, Object?>{
          'selected': museumState.selectedArtifact?.place,
          'uid': museumState.lastDetectedUid,
          'revision': museumState.nfcDetectionRevision,
        },
        <String, Object?>{'selected': 'Japan', 'uid': _japanUid, 'revision': 1},
      );
      expect(find.byKey(const ValueKey('nfc-magnet-reveal')), findsOneWidget);
      expect(find.text('JAPAN'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('start-trip-experience')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.byKey(const ValueKey('trip-memory-gallery')), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android custom-scheme trip link opens its magnet reveal', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        'everafter:///nfc/south-korea';
    try {
      await tester.pumpWidget(
        const ProviderScope(child: EverAfterApp(showSplash: false)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.byKey(const ValueKey('nfc-magnet-reveal')), findsOneWidget);
      expect(find.text('SOUTH\nKOREA'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('start-trip-experience')),
        findsOneWidget,
      );
    } finally {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _FakeAndroidNfcService implements NfcService {
  _FakeAndroidNfcService(this.uid);

  final String uid;
  final _controller = StreamController<String>.broadcast(sync: true);
  int scanCount = 0;
  bool hadListenerWhenScanned = false;

  @override
  Stream<String> get detectedUids => _controller.stream;

  @override
  Future<String?> startScan() async {
    scanCount += 1;
    hadListenerWhenScanned = _controller.hasListener;
    _controller.add(uid);
    return uid;
  }

  @override
  Future<void> scanDemo(String uid) async => _controller.add(uid);

  @override
  void dispose() => _controller.close();
}
