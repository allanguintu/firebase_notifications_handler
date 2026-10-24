// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:firebase_notifications_handler/firebase_notifications_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async { await Firebase.initializeApp(); });
  tearDown(() { debugDefaultTargetPlatformOverride = null; });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('current handler passes foreground presentation to $platform plugin', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      if (platform == TargetPlatform.iOS) {
        IOSFlutterLocalNotificationsPlugin.registerWith();
      } else {
        AndroidFlutterLocalNotificationsPlugin.registerWith();
      }
      final calls = <MethodCall>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/firebase_messaging'), (_) async => null);
      messenger.setMockMethodCallHandler(const MethodChannel('dexterous.com/flutter/local_notifications'), (call) async {
        calls.add(call);
        return call.method == 'initialize' ? true : null;
      });
      var receipts = 0;
      var arrivals = 0;
      await tester.pumpWidget(FirebaseNotificationsHandler(
        requestPermissionsOnInitialize: false,
        handleInitialMessage: false,
        shouldHandleNotification: (_) { receipts++; return true; },
        onOpenNotificationArrive: (_) { arrivals++; },
        child: const SizedBox(),
      ));
      await tester.pumpAndSettle();
      final message = RemoteMessage.fromMap({
        'messageId': 'ring-test',
        'data': <String, dynamic>{},
        'notification': {
          'title': 'Order', 'body': 'Test',
          'apple': {'sound': {'name': 'phone_ring.wav'}},
        },
      });
      FirebaseMessagingPlatform.onMessage.add(message);
      await tester.pumpAndSettle();
      expect(receipts, 1);
      expect(arrivals, 1);
      final show = calls.singleWhere((c) => c.method == 'show');
      expect(show.arguments['title'], 'Order');
      if (platform == TargetPlatform.iOS) {
        final specifics = show.arguments['platformSpecifics'];
        expect(specifics['sound'], 'phone_ring.wav');
        for (final key in ['presentAlert', 'presentSound', 'presentBanner', 'presentList']) {
          expect(specifics[key], true, reason: key);
        }
      }
      FirebaseMessagingPlatform.onMessage.add(message);
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'show'), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
