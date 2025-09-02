import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:instant_chat_app/providers/conversation_provider.dart';
import 'package:instant_chat_app/providers/user_provider.dart';
import 'package:instant_chat_app/providers/chat_provider.dart';
import 'package:instant_chat_app/screens/splash_screen.dart';
import 'package:instant_chat_app/theme/app_theme.dart';
import 'package:instant_chat_app/utils/firebase_test.dart';
import 'firebase_options.dart';
import 'package:instant_chat_app/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 MAIN: Starting app initialization...');

  try {
    debugPrint('🚀 MAIN: Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🚀 MAIN: ✅ Firebase initialized successfully');

    // Initialize notifications (FCM)
    try {
      await NotificationService().init();
      final token = await NotificationService().getToken();
      debugPrint('FCM token: $token');
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }

    // Test Firebase connection
    debugPrint('🚀 MAIN: Running Firebase connection test...');
    await FirebaseTest.testFirebaseConnection();
    debugPrint('🚀 MAIN: ✅ Firebase test completed');
  } catch (e) {
    debugPrint('🚀 MAIN: ❌ Firebase initialization failed: $e');
  }

  debugPrint('🚀 MAIN: Starting Flutter app...');
  runApp(const InstantChatApp());
}

class InstantChatApp extends StatelessWidget {
  const InstantChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer3<UserProvider, ConversationProvider, ChatProvider>(
        builder: (context, userProvider, conversationProvider, chatProvider, child) {
          // Set up callbacks between providers
          userProvider.onUserReady = (user) {
            conversationProvider.loadConversations(user.id);
          };

          userProvider.onUserLogout = () {
            conversationProvider.clearCurrentConversation();
          };

          return MaterialApp(
            title: 'Direct Messages',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            home: const SplashScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
