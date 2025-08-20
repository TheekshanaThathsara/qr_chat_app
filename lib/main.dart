import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:instant_chat_app/providers/chat_provider.dart';
import 'package:instant_chat_app/providers/user_provider.dart';
import 'package:instant_chat_app/screens/splash_screen.dart';
import 'package:instant_chat_app/utils/app_theme.dart';

void main() {
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
      child: MaterialApp(
        title: 'Instant Chat',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

