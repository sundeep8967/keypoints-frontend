import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'injection_container.dart' as di;
import 'presentation/pages/news_feed_page.dart';
import 'services/local_storage_service.dart';
import 'services/supabase_service.dart';
import 'screens/language_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure system navigation theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  
  // Enable edge-to-edge mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  // Initialize Supabase with secure configuration
  try {
    await SupabaseService.initialize();
  } catch (e) {
    print('Supabase initialization error: $e');
  }
  
  // Initialize dependency injection
  await di.init();
  
  runApp(const CleanNewsApp());
}

class CleanNewsApp extends StatelessWidget {
  const CleanNewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'News - Clean Architecture',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
        scaffoldBackgroundColor: CupertinoColors.transparent,
      ),
      home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _isFirstTime = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeSetup();
  }

  Future<void> _checkFirstTimeSetup() async {
    try {
      final isCompleted = await LocalStorageService.isFirstTimeSetupCompleted();
      setState(() {
        _isFirstTime = !isCompleted;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking first-time setup: $e');
      setState(() {
        _isFirstTime = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoActivityIndicator(
                radius: 20,
                color: CupertinoColors.white,
              ),
              SizedBox(height: 16),
              Text(
                'News',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isFirstTime) {
      return const LanguageSelectionScreen();
    }

    return const NewsFeedPage();
  }
}