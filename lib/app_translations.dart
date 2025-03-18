
import 'package:get/get.dart';

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