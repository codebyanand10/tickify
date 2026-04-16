import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  // Disable persistence to fix "INTERNAL ASSERTION FAILED (ID: b815)" on Web
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  await Supabase.initialize(
    url: 'https://yfqnmxopwowopnxlelyk.supabase.co',
    anonKey: 'sb_publishable_ILBFhXnIKPt9bP2RK97btg_HgnHU7QK',
  ); await NotificationService().initialize();
  
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return MainShell(toggleTheme: toggleTheme);
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
