import 'package:flutter/foundation.dart';

// NotificationService stub
// This file intentionally does not require `firebase_messaging` so the
// project can be analyzed and run without FCM. To enable full FCM support,
// add `firebase_messaging` to `pubspec.yaml` and replace the implementations
// below with real FirebaseMessaging calls.

typedef RemoteMessageCallback = Future<void> Function(dynamic message);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// No-op initialization in stub mode.
  Future<void> init({RemoteMessageCallback? onMessage}) async {
    debugPrint('NotificationService.init: running in stub mode (FCM disabled)');
    // Intentionally not initializing firebase_messaging here.
  }

  /// Returns null in stub mode. When FCM is enabled, return the device token.
  Future<String?> getToken() async {
    debugPrint('NotificationService.getToken: stub mode, returning null');
    return null;
  }
}

Future<void> firebaseBackgroundMessageHandler(dynamic message) async {
  debugPrint('firebaseBackgroundMessageHandler: stub invoked (FCM disabled)');
}
