import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (skip for now to test basic app)
  try {
    // Commented out for initial testing without Firebase setup
    // await Firebase.initializeApp(
    //   options: DefaultFirebaseOptions.currentPlatform,
    // );
    print('Firebase initialization skipped for testing');
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  runApp(const KeyPointsApp());
}

class KeyPointsApp extends StatelessWidget {
  const KeyPointsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'KeyPoints',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
