import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'theme.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Supabase.initialize(
    url: 'https://yfqnmxopwowopnxlelyk.supabase.co',
    anonKey: 'sb_publishable_ILBFhXnIKPt9bP2RK97btg_HgnHU7QK',
  );
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(const TickifyApp());
}

class TickifyApp extends StatefulWidget {
  const TickifyApp({super.key});

  @override
  State<TickifyApp> createState() => _TickifyAppState();
}

class _TickifyAppState extends State<TickifyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tickify',
      restorationScopeId: 'tickify',
      themeMode: _themeMode,
      theme: appThemeLight,
      darkTheme: appThemeDark,

      //  THIS decides which screen to show
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {

          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          
          if (snapshot.hasData) {
            return MainShell(toggleTheme: toggleTheme);
          }

          // Not logged in → LoginScreen
          return const LoginScreen();
        },
      ),
    );
  }
}