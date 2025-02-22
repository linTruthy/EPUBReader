import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:html/parser.dart' show parse;

class ReaderController extends GetxController {
  RxInt currentChapter = 0.obs;
  RxDouble fontSize = 16.0.obs;
  RxString currentTheme = 'Default'.obs;
  late EpubBook epubBook;
  RxList<Map<String, dynamic>> bookmarks = <Map<String, dynamic>>[].obs;
  RxMap<String, dynamic> readingStats = <String, dynamic>{}.obs;
  RxList<Map<String, String>> annotations = <Map<String, String>>[].obs;

  final Map<String, Color> themes = {
    'Default': Colors.blueGrey,
    'Sepia': Colors.brown[300]!,
    'Night': Colors.grey[900]!,
  };

  @override
  void onInit() {
    super.onInit();
    _loadStats();
  }

  void changeChapter(int index) {
    currentChapter.value = index;
    _updateStats();
    saveProgress();
  }

  void changeFontSize(double size) => fontSize.value = size;
  void toggleTheme(String theme) => currentTheme.value = theme;

  Future<void> saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastChapter', currentChapter.value);
    await prefs.setStringList(
      'bookmarks',
      bookmarks.map((b) => '${b['chapter']}:${b['text']}').toList(),
    );
  }

  void addBookmark(String text) {
    bookmarks.add({
      'chapter': currentChapter.value,
      'text': text.substring(0, text.length > 50 ? 50 : text.length),
      'date': DateTime.now().toString(),
    });
    saveProgress();
  }

  void addAnnotation(String text, String note) {
    annotations.add({
      'chapter': currentChapter.value.toString(),
      'text': text,
      'note': note,
      'date': DateTime.now().toString(),
    });
  }

  List<EpubChapter> searchBook(String query) {
    return epubBook.Chapters!.where((chapter) =>
        (chapter.HtmlContent?.toLowerCase() ?? '').contains(query.toLowerCase())).toList();
  }

  void _updateStats() {
    readingStats.value = {
      'chaptersRead': currentChapter.value + 1,
      'totalChapters': epubBook.Chapters?.length ?? 0,
      'lastRead': DateTime.now().toString(),
      'progress': ((currentChapter.value + 1) / (epubBook.Chapters?.length ?? 1) * 100).toStringAsFixed(1),
    };
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBookmarks = prefs.getStringList('bookmarks') ?? [];
    bookmarks.value = savedBookmarks.map((b) {
      final parts = b.split(':');
      return {'chapter': int.parse(parts[0]), 'text': parts[1], 'date': DateTime.now().toString()};
    }).toList();
  }

  String getPlainText(String htmlContent) {
    final document = parse(htmlContent);
    return document.body?.text ?? '';
  }
}

class ReaderScreen extends StatefulWidget {
  final String filePath;
  const ReaderScreen({super.key, required this.filePath});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with SingleTickerProviderStateMixin {
  final controller = Get.put(ReaderController());
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadEpub();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadEpub() async {
    final bytes = await File(widget.filePath).readAsBytes();
    controller.epubBook = await EpubReader.readBook(bytes);
    setState(() {});
  }

  void _showSelectionDialog(String selectedText) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Selected Text', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(selectedText, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      controller.addAnnotation(selectedText, 'Quoted from ${controller.epubBook.Title}');
                      Get.back();
                      Get.snackbar('Quote', 'Text saved as annotation', snackPosition: SnackPosition.TOP);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Quote'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Share.share(
                        '"$selectedText" - ${controller.epubBook.Title}',
                        subject: 'Quote from ${controller.epubBook.Title}',
                      );
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Share'),
                  ),
                  TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
                ],
              ),
            ],
          ),
        ),
      ),
      transitionDuration: const Duration(milliseconds: 300),
      transitionCurve: Curves.easeInOut,
    );
  }

  Widget _buildAnimatedIcon(IconData icon, VoidCallback onPressed) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: () {
          _animationController.forward(from: 0);
          onPressed();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => Scaffold(
          backgroundColor: controller.themes[controller.currentTheme.value],
          appBar: AppBar(
            backgroundColor: controller.themes[controller.currentTheme.value]?.withOpacity(0.9),
            elevation: 2,
            shadowColor: Colors.black26,
            title: Text(
              controller.epubBook.Title ?? 'Reading',
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              _buildAnimatedIcon(Icons.search, _showSearchDialog),
              _buildAnimatedIcon(Icons.bookmark_add, _addBookmark),
              _buildAnimatedIcon(Icons.edit_note, _addAnnotation),
              _buildAnimatedIcon(Icons.format_size, _showFontSizeDialog),
              _buildAnimatedIcon(Icons.palette, _showThemeDialog),
            ],
          ),
          drawer: _buildDrawer(),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: controller.epubBook == null
                ? const Center(child: CircularProgressIndicator())
                : PageView.builder(
                    itemCount: controller.epubBook.Chapters?.length ?? 0,
                    onPageChanged: (index) {
                      controller.changeChapter(index);
                      _animationController.forward(from: 0); // Trigger fade on page change
                    },
                    itemBuilder: (context, index) {
                      final chapter = controller.epubBook.Chapters![index];
                      final plainText = controller.getPlainText(chapter.HtmlContent ?? '');
                      return SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(20),
                        child: GestureDetector(
                          onLongPress: _addAnnotation,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: controller.currentTheme.value == 'Night' ? Colors.grey[800] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: SelectableText(
                              plainText,
                              style: TextStyle(
                                fontSize: controller.fontSize.value,
                                color: controller.currentTheme.value == 'Night' ? Colors.white : Colors.black87,
                                height: 1.5,
                              ),
                              onSelectionChanged: (selection, cause) {
                                if (selection.isValid && cause == SelectionChangedCause.longPress) {
                                  final selectedText = plainText.substring(selection.start, selection.end);
                                  _showSelectionDialog(selectedText);
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ));
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [controller.themes[controller.currentTheme.value]!, Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.epubBook.Title ?? 'Contents',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Progress: ${controller.readingStats['progress'] ?? '0'}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          _buildDrawerTile(Icons.bar_chart, 'Reading Statistics', _showStatsDialog),
          _buildDrawerTile(Icons.bookmarks, 'Bookmarks', _showBookmarksDialog),
          _buildDrawerTile(Icons.notes, 'Annotations', _showAnnotationsDialog),
          const Divider(color: Colors.white24),
          ...(controller.epubBook.Chapters ?? []).map((chapter) => _buildDrawerTile(
                Icons.book,
                chapter.Title ?? 'Chapter',
                () {
                  controller.changeChapter(controller.epubBook.Chapters!.indexOf(chapter));
                  Get.back();
                },
              )),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, VoidCallback onTap) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: ListTile(
        leading: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Icon(icon, key: ValueKey('$title-${controller.currentTheme.value}'), color: Colors.blueGrey),
        ),
        title: Text(title, style: const TextStyle(color: Colors.blueGrey)),
        onTap: onTap,
      ),
    );
  }

  void _showSearchDialog() {
    final TextEditingController searchController = TextEditingController();
    Get.dialog(
      _buildAnimatedDialog(
        title: 'Search',
        content: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Enter search term',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final results = controller.searchBook(searchController.text);
              Get.back();
              if (results.isNotEmpty) controller.changeChapter(controller.epubBook.Chapters!.indexOf(results.first));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _addBookmark() {
    final chapter = controller.epubBook.Chapters![controller.currentChapter.value];
    controller.addBookmark(chapter.HtmlContent ?? '');
    Get.snackbar('Bookmark', 'Added bookmark for current page', snackPosition: SnackPosition.TOP);
  }

  void _addAnnotation() {
    final TextEditingController noteController = TextEditingController();
    Get.dialog(
      _buildAnimatedDialog(
        title: 'Add Annotation',
        content: TextField(
          controller: noteController,
          decoration: InputDecoration(
            hintText: 'Enter your note',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              final chapter = controller.epubBook.Chapters![controller.currentChapter.value];
              controller.addAnnotation(chapter.HtmlContent?.substring(0, 50) ?? '', noteController.text);
              Get.back();
              Get.snackbar('Annotation', 'Annotation added', snackPosition: SnackPosition.TOP);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog() {
    Get.dialog(
      _buildAnimatedDialog(
        title: 'Reading Statistics',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chapters Read: ${controller.readingStats['chaptersRead']}', style: Theme.of(context).textTheme.bodyMedium),
            Text('Total Chapters: ${controller.readingStats['totalChapters']}', style: Theme.of(context).textTheme.bodyMedium),
            Text('Progress: ${controller.readingStats['progress']}%', style: Theme.of(context).textTheme.bodyMedium),
            Text('Last Read: ${controller.readingStats['lastRead']}', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        actions: [TextButton(onPressed: () => Get.back(), child: const Text('OK', style: TextStyle(color: Colors.blueGrey)))],
      ),
    );
  }

  void _showBookmarksDialog() {
    Get.dialog(
      _buildAnimatedDialog(
        title: 'Bookmarks',
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: controller.bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = controller.bookmarks[index];
              return ListTile(
                title: Text(bookmark['text'], style: Theme.of(context).textTheme.bodyMedium),
                subtitle: Text(bookmark['date'], style: Theme.of(context).textTheme.bodySmall),
                onTap: () {
                  controller.changeChapter(bookmark['chapter']);
                  Get.back();
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Get.back(), child: const Text('Close', style: TextStyle(color: Colors.blueGrey)))],
      ),
    );
  }

  void _showAnnotationsDialog() {
    Get.dialog(
      _buildAnimatedDialog(
        title: 'Annotations',
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: controller.annotations.length,
            itemBuilder: (context, index) {
              final annotation = controller.annotations[index];
              return ListTile(
                title: Text(annotation['note']!, style: Theme.of(context).textTheme.bodyMedium),
                subtitle: Text(annotation['text']!, style: Theme.of(context).textTheme.bodySmall),
                onTap: () {
                  controller.changeChapter(int.parse(annotation['chapter']!));
                  Get.back();
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Get.back(), child: const Text('Close', style: TextStyle(color: Colors.blueGrey)))],
      ),
    );
  }

  void _showThemeDialog() {
    Get.dialog(
      _buildAnimatedDialog(
        title: 'Select Theme',
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: controller.themes.keys.map((theme) => ListTile(
                  title: Text(theme, style: Theme.of(context).textTheme.bodyMedium),
                  onTap: () {
                    controller.toggleTheme(theme);
                    Get.back();
                  },
                )).toList(),
          ),
        ),
      ),
    );
  }

  void _showFontSizeDialog() {
    Get.dialog(
      _buildAnimatedDialog(
        title: 'Font Size',
        content: Slider(
          value: controller.fontSize.value,
          min: 12,
          max: 24,
          divisions: 6,
          onChanged: controller.changeFontSize,
          activeColor: Colors.blueGrey.shade700,
          inactiveColor: Colors.grey[300],
        ),
        actions: [TextButton(onPressed: () => Get.back(), child: const Text('OK', style: TextStyle(color: Colors.blueGrey)))],
      ),
    );
  }

  Widget _buildAnimatedDialog({required String title, required Widget content, List<Widget>? actions}) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.blueGrey.shade800)),
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 16),
            if (actions != null)
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }
}