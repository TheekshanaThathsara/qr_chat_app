import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:instant_chat_app/providers/chat_provider.dart';
import 'package:instant_chat_app/providers/user_provider.dart';
import 'package:instant_chat_app/screens/splash_screen.dart';
import 'package:instant_chat_app/utils/app_theme.dart';
import 'package:instant_chat_app/utils/firebase_test.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 MAIN: Starting app initialization...');

  try {
    debugPrint('🚀 MAIN: Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🚀 MAIN: ✅ Firebase initialized successfully');

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
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer2<UserProvider, ChatProvider>(
        builder: (context, userProvider, chatProvider, child) {
          // Set up callbacks between providers
          userProvider.onUserReady = (user) {
            chatProvider.initializeChat(user);
          };

          userProvider.onUserLogout = () {
            chatProvider.disconnect();
          };

          return MaterialApp(
            title: 'Instant Chat',
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
