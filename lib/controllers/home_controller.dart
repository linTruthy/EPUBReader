import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myapp/models/recent_book.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeController extends GetxController {
  RxList<RecentBook> recentBooks = <RecentBook>[].obs;
  RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadRecentBooks();
  }

  Future<void> loadRecentBooks() async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final booksJson = prefs.getStringList('recentBooks') ?? [];

      recentBooks.value =
          booksJson
              .map((json) => RecentBook.fromJson(jsonDecode(json)))
              .toList()
            ..sort((a, b) => b.lastRead.compareTo(a.lastRead));
    } catch (e) {
      debugPrint('Error loading recent books: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addRecentBook(RecentBook book) async {
    try {
      // Remove if exists and add to beginning
      recentBooks.removeWhere((item) => item.filePath == book.filePath);
      recentBooks.insert(0, book);

      // Keep only the 10 most recent books
      if (recentBooks.length > 10) {
        recentBooks.removeLast();
      }

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      final booksJson =
          recentBooks.map((book) => jsonEncode(book.toJson())).toList();

      await prefs.setStringList('recentBooks', booksJson);
    } catch (e) {
      debugPrint('Error saving recent book: $e');
    }
  }
}
