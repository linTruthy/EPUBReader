// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'EPUB Reader',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Follow system theme by default
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const HomeScreen(),
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),
      popGesture: true, // Enable swipe to go back
      translations: AppTranslations(),
      locale: Get.deviceLocale,
      fallbackLocale: const Locale('en', 'US'),
    );
  }
}

// Internationalization support
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {
      'app_name': 'EPUB Reader',
      'open_file': 'Open EPUB File',
      'welcome': 'Dive into your favorite books',
      'recent_books': 'Recent Books',
      'no_books': 'No recent books found',
    },
    'es_ES': {
      'app_name': 'Lector EPUB',
      'open_file': 'Abrir archivo EPUB',
      'welcome': 'Sumérgete en tus libros favoritos',
      'recent_books': 'Libros recientes',
      'no_books': 'No se encontraron libros recientes',
    },
    // Add more languages as needed
  };
}