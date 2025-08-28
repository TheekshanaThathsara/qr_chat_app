# instant_chat_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase Cloud Messaging (optional but recommended)

This project can use FCM to surface incoming messages when the app is
backgrounded. To enable it:

1. Add dependency in `pubspec.yaml`:

```yaml
firebase_messaging: ^14.0.0
```

2. Follow platform setup steps from the Firebase docs to register the
	background message handler and add the required native config.

3. The app initializes `NotificationService` at startup and will print the
	device FCM token to the console. Use that for testing sends from the
	Firebase console.

