import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:html/parser.dart' show parse;
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class ReaderController extends GetxController {
  // Book state
  RxInt currentChapter = 0.obs;
  RxDouble fontSize = 16.0.obs;
  RxString currentTheme = 'Default'.obs;
  EpubBook? epubBook;
  String? bookFilePath;

  // Reading preferences
  RxDouble lineHeight = 1.5.obs;
  RxString fontFamily = 'Roboto'.obs;
  RxBool isDictionaryEnabled = true.obs;
  RxBool isVoiceoverEnabled = false.obs;
  RxDouble readingPosition = 0.0.obs;
  RxBool showPageNumbers = true.obs;
  RxBool isLoading = true.obs;

  // User data
  RxList<Map<String, dynamic>> bookmarks = <Map<String, dynamic>>[].obs;
  RxMap<String, dynamic> readingStats = <String, dynamic>{}.obs;
  RxList<Map<String, String>> annotations = <Map<String, String>>[].obs;
  RxList<String> highlights = <String>[].obs;

  final fonts = [
    'Roboto',
    'Merriweather',
    'OpenDyslexic',
    'Georgia',
    'Literata',
  ];
  final lineHeights = [1.3, 1.5, 1.8, 2.0, 2.2];

  void toggleDictionary(bool value) => isDictionaryEnabled.value = value;
  void toggleVoiceover(bool value) => isVoiceoverEnabled.value = value;
  void togglePageNumbers(bool value) => showPageNumbers.value = value;

  @override
  void onInit() {
    super.onInit();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    fontSize.value = prefs.getDouble('fontSize') ?? 16.0;
    fontFamily.value = prefs.getString('fontFamily') ?? 'Roboto';
    lineHeight.value = prefs.getDouble('lineHeight') ?? 1.5;
    currentTheme.value = prefs.getString('readerTheme') ?? 'Default';
    isDictionaryEnabled.value = prefs.getBool('isDictionaryEnabled') ?? true;
    isVoiceoverEnabled.value = prefs.getBool('isVoiceoverEnabled') ?? false;
    showPageNumbers.value = prefs.getBool('showPageNumbers') ?? true;
  }

  Future<void> loadBook(String filePath) async {
    isLoading.value = true;
    try {
      final bytes = await File(filePath).readAsBytes();
      epubBook = await EpubReader.readBook(bytes);
      bookFilePath = filePath;

      // Load previous reading progress for this book
      await _loadBookData(filePath);
      _updateStats();
      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Could not load book: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  void changeChapter(int index) {
    if (index >= 0 &&
        epubBook != null &&
        index < (epubBook!.Chapters?.length ?? 0)) {
      currentChapter.value = index;
      readingPosition.value = 0.0;
      _updateStats();
      saveProgress();
    }
  }

  void updateReadingPosition(double position) {
    readingPosition.value = position;
    _updateStats();
    saveProgress();
  }

  void changeFontSize(double size) {
    fontSize.value = size;
    _savePreferences();
  }

  void changeLineHeight(double height) {
    lineHeight.value = height;
    _savePreferences();
  }

  void changeFontFamily(String font) {
    fontFamily.value = font;
    _savePreferences();
  }

  void toggleTheme(String theme) {
    currentTheme.value = theme;
    _savePreferences();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', fontSize.value);
    await prefs.setString('fontFamily', fontFamily.value);
    await prefs.setDouble('lineHeight', lineHeight.value);
    await prefs.setString('readerTheme', currentTheme.value);
    await prefs.setBool('isDictionaryEnabled', isDictionaryEnabled.value);
    await prefs.setBool('isVoiceoverEnabled', isVoiceoverEnabled.value);
    await prefs.setBool('showPageNumbers', showPageNumbers.value);
  }

  Future<void> saveProgress() async {
    if (epubBook == null || bookFilePath == null) return;

    try {
      final bookId = _generateBookId(bookFilePath!);
      final prefs = await SharedPreferences.getInstance();

      // Save data specific to this book
      await prefs.setInt('${bookId}_lastChapter', currentChapter.value);
      await prefs.setDouble('${bookId}_readingPosition', readingPosition.value);

      // Save bookmarks
      await prefs.setStringList(
        '${bookId}_bookmarks',
        bookmarks
            .map((b) => '${b['chapter']}:${b['position']}:${b['text']}')
            .toList(),
      );

      // Save annotations
      await prefs.setStringList(
        '${bookId}_annotations',
        annotations
            .map(
              (a) =>
                  '${a['chapter']}:${a['position']}:${a['text']}:${a['note']}',
            )
            .toList(),
      );

      // Save highlights
      await prefs.setStringList('${bookId}_highlights', highlights);

      // Save reading stats
      await prefs.setString('${bookId}_stats', _encodeStats());
    } catch (e) {
      debugPrint('Error saving reading progress: $e');
    }
  }

  Future<void> _loadBookData(String filePath) async {
    try {
      final bookId = _generateBookId(filePath);
      final prefs = await SharedPreferences.getInstance();

      // Load previous chapter position
      currentChapter.value = prefs.getInt('${bookId}_lastChapter') ?? 0;
      readingPosition.value =
          prefs.getDouble('${bookId}_readingPosition') ?? 0.0;

      // Load bookmarks
      final savedBookmarks = prefs.getStringList('${bookId}_bookmarks') ?? [];
      bookmarks.value =
          savedBookmarks.map((b) {
            final parts = b.split(':');
            return {
              'chapter': int.parse(parts[0]),
              'position': double.parse(parts[1]),
              'text': parts.length > 2 ? parts[2] : 'Bookmark',
              'date': DateTime.now().toString(),
            };
          }).toList();

      // Load annotations
      final savedAnnotations =
          prefs.getStringList('${bookId}_annotations') ?? [];
      annotations.value =
          savedAnnotations.map((a) {
            final parts = a.split(':');
            return {
              'chapter': parts[0],
              'position': parts[1],
              'text': parts.length > 2 ? parts[2] : '',
              'note': parts.length > 3 ? parts[3] : '',
              'date': DateTime.now().toString(),
            };
          }).toList();

      // Load highlights
      highlights.value = prefs.getStringList('${bookId}_highlights') ?? [];

      // Load reading stats
      final statsJson = prefs.getString('${bookId}_stats');
      if (statsJson != null) {
        _decodeStats(statsJson);
      }
    } catch (e) {
      debugPrint('Error loading book data: $e');
    }
  }

  void addBookmark(String text, double position) {
    if (text.isEmpty) return;

    bookmarks.add({
      'chapter': currentChapter.value,
      'position': position,
      'text': text.substring(0, text.length > 50 ? 50 : text.length),
      'date': DateTime.now().toString(),
    });

    saveProgress();
  }

  void addAnnotation(String text, String note, double position) {
    annotations.add({
      'chapter': currentChapter.value.toString(),
      'position': position.toString(),
      'text': text,
      'note': note,
      'date': DateTime.now().toString(),
    });

    saveProgress();
  }

  void addHighlight(String text) {
    if (!highlights.contains(text)) {
      highlights.add(text);
      saveProgress();
    }
  }

  void removeHighlight(String text) {
    highlights.remove(text);
    saveProgress();
  }

  List<EpubChapter>? searchBook(String query) {
    if (epubBook == null || query.isEmpty) return [];
    return epubBook!.Chapters
        ?.where(
          (chapter) => (chapter.HtmlContent?.toLowerCase() ?? '').contains(
            query.toLowerCase(),
          ),
        )
        .toList();
  }

  void _updateStats() {
    if (epubBook == null) return;

    final totalChapters = epubBook!.Chapters?.length ?? 0;
    if (totalChapters == 0) return;

    // Calculate progress percentage (considering both chapter and position within chapter)
    final chapterProgress = currentChapter.value / totalChapters;
    final positionProgress = readingPosition.value / 100; // Normalize to 0-1
    final combinedProgress =
        ((chapterProgress + (positionProgress / totalChapters)) * 100);

    readingStats.value = {
      'chaptersRead': currentChapter.value + 1,
      'totalChapters': totalChapters,
      'lastRead': DateTime.now().toString(),
      'progress': combinedProgress.toStringAsFixed(1),
      'sessionTime': readingStats['sessionTime'] ?? 0,
      'totalTime': (readingStats['totalTime'] ?? 0) + 1,
      'startDate': readingStats['startDate'] ?? DateTime.now().toString(),
    };
  }

  String _encodeStats() {
    return readingStats.toString(); // Simple encoding for now
  }

  void _decodeStats(String encoded) {
    // Simple decoding - would be better with proper JSON in a real app
    readingStats.value = {'decoded': encoded};
  }

  String _generateBookId(String filePath) {
    // Create a unique ID for the book based on path
    return filePath.split('/').last.replaceAll('.epub', '');
  }

  String getPlainText(String htmlContent) {
    final document = parse(htmlContent);
    return document.body?.text ?? '';
  }

  // Text-to-speech functionality
  bool isSpeaking = false;
  Timer? _timer;

  void startReading(String text) {
    if (isVoiceoverEnabled.value) {
      isSpeaking = true;
      // Mock implementation - would use a TTS engine in a real app
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        // Update reading position while speaking
      });

      // Simulate reading for demo purposes
      Future.delayed(const Duration(seconds: 10), () {
        stopReading();
      });
    }
  }

  void stopReading() {
    isSpeaking = false;
    _timer?.cancel();
  }

  // For returning data to home screen
  Map<String, dynamic> getReturnData() {
    final progress = double.tryParse(readingStats['progress'] ?? '0.0') ?? 0.0;
    return {
      'title': epubBook?.Title ?? 'Unknown Book',
      'progress': progress,
      'lastRead': DateTime.now().toString(),
    };
  }
}

class ReaderScreen extends StatefulWidget {
  final String filePath;
  const ReaderScreen({super.key, required this.filePath});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SingleTickerProviderStateMixin {
  final controller = Get.put(ReaderController());
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // For page turning gestures
  double _startDragX = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _initializeReader();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();

    // Add scroll listener to track reading position
    _scrollController.addListener(_updateReadingPosition);

    // Set system UI overlay style based on theme
    _updateSystemUI();
  }

  void _updateSystemUI() {
    final theme = AppTheme.readerThemes[controller.currentTheme.value];
    if (theme == null) return;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: theme.brightness,
        statusBarIconBrightness:
            theme.brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
        systemNavigationBarColor: theme.backgroundColor,
        systemNavigationBarIconBrightness:
            theme.brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
      ),
    );
  }

  void _updateReadingPosition() {
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      final position =
          _scrollController.offset /
          _scrollController.position.maxScrollExtent *
          100;
      controller.updateReadingPosition(position);
    }
  }

  Future<void> _initializeReader() async {
    await controller.loadBook(widget.filePath);

    // Set the scroll position after book is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          controller.readingPosition.value > 0) {
        final scrollTo =
            _scrollController.position.maxScrollExtent *
            (controller.readingPosition.value / 100);
        _scrollController.jumpTo(
          scrollTo.clamp(0, _scrollController.position.maxScrollExtent),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.removeListener(_updateReadingPosition);
    _scrollController.dispose();

    // Return book data to previous screen
    Get.back(result: controller.getReturnData());
    super.dispose();
  }

  void _showSelectionDialog(String selectedText, double position) {
    final readerTheme = AppTheme.readerThemes[controller.currentTheme.value]!;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: readerTheme.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Selected Text',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: readerTheme.textColor,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: readerTheme.textColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selectedText,
                  style: TextStyle(
                    color: readerTheme.textColor,
                    fontSize: controller.fontSize.value * 0.9,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildActionButton(
                    icon: Icons.bookmark_add,
                    label: 'Bookmark',
                    color: Colors.blue,
                    onPressed: () {
                      controller.addBookmark(selectedText, position);
                      Get.back();
                      _showSuccessSnackbar('Bookmark added');
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.note_add,
                    label: 'Annotate',
                    color: Colors.green,
                    onPressed:
                        () => _showAnnotationDialog(selectedText, position),
                  ),
                  _buildActionButton(
                    icon: Icons.highlight,
                    label: 'Highlight',
                    color: Colors.amber,
                    onPressed: () {
                      controller.addHighlight(selectedText);
                      Get.back();
                      _showSuccessSnackbar('Text highlighted');
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.share,
                    label: 'Share',
                    color: Colors.purple,
                    onPressed: () {
                      final bookTitle = controller.epubBook?.Title ?? 'my book';
                      Share.share(
                        '"$selectedText" - from $bookTitle',
                        subject: 'Quote from $bookTitle',
                      );
                      Get.back();
                    },
                  ),
                  if (controller.isDictionaryEnabled.value)
                    _buildActionButton(
                      icon: Icons.search,
                      label: 'Define',
                      color: Colors.teal,
                      onPressed: () {
                        Get.back();
                        _lookupDefinition(selectedText);
                      },
                    ),
                  _buildActionButton(
                    icon: Icons.close,
                    label: 'Cancel',
                    color: Colors.grey,
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      transitionDuration: const Duration(milliseconds: 200),
      transitionCurve: Curves.easeInOut,
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnnotationDialog(String selectedText, double position) {
    final TextEditingController noteController = TextEditingController();
    final readerTheme = AppTheme.readerThemes[controller.currentTheme.value]!;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: readerTheme.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Note',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: readerTheme.textColor,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: readerTheme.textColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selectedText,
                  style: TextStyle(
                    color: readerTheme.textColor,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                style: TextStyle(color: readerTheme.textColor),
                decoration: InputDecoration(
                  hintText: 'Enter your note',
                  hintStyle: TextStyle(
                    color: readerTheme.textColor.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: readerTheme.textColor.withOpacity(0.05),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: readerTheme.accentColor),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: readerTheme.accentColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      controller.addAnnotation(
                        selectedText,
                        noteController.text,
                        position,
                      );
                      Get.back();
                      Get.back();
                      _showSuccessSnackbar('Note added');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: readerTheme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _lookupDefinition(String word) {
    // Show a mock dictionary definition
    final readerTheme = AppTheme.readerThemes[controller.currentTheme.value]!;
    final shorterWord = word
        .split(' ')
        .first
        .replaceAll(RegExp(r'[^\w\s]'), '');

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: readerTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  shorterWord,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: readerTheme.textColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: readerTheme.textColor),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '/ mɒk def.ɪˈnɪʃ(ə)n /',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: readerTheme.textColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'noun',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: readerTheme.accentColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '1. This is a mock dictionary definition for demonstration purposes.',
              style: TextStyle(color: readerTheme.textColor),
            ),
            const SizedBox(height: 8),
            Text(
              '2. In a real app, this would connect to a dictionary API.',
              style: TextStyle(color: readerTheme.textColor),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.volume_up),
                label: const Text('Pronounce'),
                onPressed: () {
                  Get.snackbar(
                    'Audio',
                    'Pronunciation would play here',
                    backgroundColor: readerTheme.accentColor.withOpacity(0.7),
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: readerTheme.accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green.withOpacity(0.7),
      colorText: Colors.white,
      margin: const EdgeInsets.all(8),
      duration: const Duration(seconds: 2),
    );
  }

  Widget _buildAnimatedIcon(
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () {
              HapticFeedback.lightImpact();
              onPressed();
            },
            child: AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: Colors.white, semanticLabel: label),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showReadingOptionsDialog() {
    final readerTheme = AppTheme.readerThemes[controller.currentTheme.value]!;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: readerTheme.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reading Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: readerTheme.textColor,
                ),
              ),
              const SizedBox(height: 24),

              // Font Size Section
              _buildSettingSection(
                title: 'Font Size',
                child: Obx(
                  () => Slider(
                    value: controller.fontSize.value,
                    min: 12,
                    max: 24,
                    divisions: 12,
                    label: controller.fontSize.value.toStringAsFixed(1),
                    onChanged: controller.changeFontSize,
                    activeColor: readerTheme.accentColor,
                  ),
                ),
              ),

              // Line Height Section
              _buildSettingSection(
                title: 'Line Height',
                child: Obx(
                  () => Slider(
                    value: controller.lineHeight.value,
                    min: 1.0,
                    max: 2.5,
                    divisions: 15,
                    label: controller.lineHeight.value.toStringAsFixed(1),
                    onChanged: controller.changeLineHeight,
                    activeColor: readerTheme.accentColor,
                  ),
                ),
              ),

              // Font Family Section
              _buildSettingSection(
                title: 'Font Family',
                child: Obx(
                  () => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        controller.fonts
                            .map(
                              (font) => ChoiceChip(
                                label: Text(font),
                                selected: controller.fontFamily.value == font,
                                onSelected: (selected) {
                                  if (selected)
                                    controller.changeFontFamily(font);
                                },
                                selectedColor: readerTheme.accentColor
                                    .withOpacity(0.7),
                                backgroundColor: readerTheme.textColor
                                    .withOpacity(0.1),
                                labelStyle: TextStyle(
                                  color:
                                      controller.fontFamily.value == font
                                          ? Colors.white
                                          : readerTheme.textColor,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ),

              // Theme Selection
              _buildSettingSection(
                title: 'Theme',
                child: SizedBox(
                  height: 60,
                  child: Obx(
                    () => ListView(
                      scrollDirection: Axis.horizontal,
                      children:
                          AppTheme.readerThemes.entries.map((entry) {
                            final theme = entry.value;
                            final isSelected =
                                controller.currentTheme.value == entry.key;

                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: InkWell(
                                onTap: () => controller.toggleTheme(entry.key),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: theme.backgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? readerTheme.accentColor
                                              : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child:
                                        isSelected
                                            ? Icon(
                                              Icons.check,
                                              color: theme.accentColor,
                                            )
                                            : null,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ),

              // Accessibility Options
              _buildSettingSection(
                title: 'Accessibility',
                child: Column(
                  children: [
                    Obx(
                      () => SwitchListTile(
                        title: Text(
                          'Text-to-Speech',
                          style: TextStyle(
                            color: readerTheme.textColor,
                            fontSize: 14,
                          ),
                        ),
                        value: controller.isVoiceoverEnabled.value,
                        onChanged: controller.toggleVoiceover,
                        activeColor: readerTheme.accentColor,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    Obx(
                      () => SwitchListTile(
                        title: Text(
                          'Dictionary Lookup',
                          style: TextStyle(
                            color: readerTheme.textColor,
                            fontSize: 14,
                          ),
                        ),
                        value: controller.isDictionaryEnabled.value,
                        onChanged: controller.toggleDictionary,
                        activeColor: readerTheme.accentColor,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    Obx(
                      () => SwitchListTile(
                        title: Text(
                          'Show Page Numbers',
                          style: TextStyle(
                            color: readerTheme.textColor,
                            fontSize: 14,
                          ),
                        ),
                        value: controller.showPageNumbers.value,
                        onChanged: controller.togglePageNumbers,
                        activeColor: readerTheme.accentColor,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Close Button
              Center(
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: readerTheme.accentColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSection({required String title, required Widget child}) {
    final readerTheme = AppTheme.readerThemes[controller.currentTheme.value]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: readerTheme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required ReaderTheme theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: theme.accentColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showBookmarksDialog() {
    final readerTheme = AppTheme.readerThemes[controller.currentTheme.value]!;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: readerTheme.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bookmarks',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: readerTheme.textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: readerTheme.textColor),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              controller.bookmarks.isEmpty
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.bookmark_outline,
                            color: readerTheme.textColor.withOpacity(0.5),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No bookmarks yet',
                            style: TextStyle(
                              color: readerTheme.textColor.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Long-press text and select "Bookmark" to add',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: readerTheme.textColor.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  : SizedBox(
                    width: double.maxFinite,
                    height: 300,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: controller.bookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = controller.bookmarks[index];
                        return Dismissible(
                          key: Key('bookmark_${index}_${bookmark['date']}'),
                          background: Container(
                            color: Colors.red.withOpacity(0.5),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) {
                            controller.bookmarks.removeAt(index);
                            controller.saveProgress();
                            _showSuccessSnackbar('Bookmark removed');
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: readerTheme.accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.bookmark,
                                color: readerTheme.accentColor,
                              ),
                            ),
                            title: Text(
                              bookmark['text'] ?? 'Bookmark',
                              style: TextStyle(
                                color: readerTheme.textColor,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  'Chapter ${bookmark['chapter'] + 1}',
                                  style: TextStyle(
                                    color: readerTheme.textColor.withOpacity(
                                      0.7,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (bookmark['date'] != null)
                                  Text(
                                    bookmark['date'].toString().split(' ')[0],
                                    style: TextStyle(
                                      color: readerTheme.textColor.withOpacity(
                                        0.5,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              controller.changeChapter(bookmark['chapter']);

                              // Jump to position if available
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (_scrollController.hasClients &&
                                    bookmark['position'] != null) {
                                  final position = double.parse(
                                    bookmark['position'].toString(),
                                  );
                                  final scrollTo =
                                      _scrollController
                                          .position
                                          .maxScrollExtent *
                                      (position / 100);
                                  _scrollController.animateTo(
                                    scrollTo.clamp(
                                      0,
                                      _scrollController
                                          .position
                                          .maxScrollExtent,
                                    ),
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                              });

                              Get.back();
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: readerTheme.textColor.withOpacity(0.1),
                                width: 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnnotationsDialog() {
    final readerTheme = AppTheme.readerThemes[controller.currentTheme.value]!;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: readerTheme.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notes & Highlights',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: readerTheme.textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: readerTheme.textColor),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),

              // Tabs for Notes and Highlights
              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.note_alt, size: 18),
                              const SizedBox(width: 8),
                              Text('Notes (${controller.annotations.length})'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.highlight, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Highlights (${controller.highlights.length})',
                              ),
                            ],
                          ),
                        ),
                      ],
                      labelColor: readerTheme.accentColor,
                      unselectedLabelColor: readerTheme.textColor.withOpacity(
                        0.7,
                      ),
                      indicatorColor: readerTheme.accentColor,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: TabBarView(
                        children: [
                          // Notes Tab
                          controller.annotations.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.note_alt_outlined,
                                      color: readerTheme.textColor.withOpacity(
                                        0.5,
                                      ),
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No notes yet',
                                      style: TextStyle(
                                        color: readerTheme.textColor
                                            .withOpacity(0.7),
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Long-press text and select "Annotate" to add',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: readerTheme.textColor
                                            .withOpacity(0.5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                itemCount: controller.annotations.length,
                                itemBuilder: (context, index) {
                                  final annotation =
                                      controller.annotations[index];
                                  return Dismissible(
                                    key: Key(
                                      'note_${index}_${annotation['date']}',
                                    ),
                                    background: Container(
                                      color: Colors.red.withOpacity(0.5),
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (_) {
                                      controller.annotations.removeAt(index);
                                      controller.saveProgress();
                                      _showSuccessSnackbar('Note removed');
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      color: readerTheme.backgroundColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: readerTheme.textColor
                                              .withOpacity(0.1),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              annotation['note'] ?? '',
                                              style: TextStyle(
                                                color: readerTheme.textColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: readerTheme.textColor
                                                    .withOpacity(0.05),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: readerTheme.textColor
                                                      .withOpacity(0.1),
                                                ),
                                              ),
                                              child: Text(
                                                annotation['text'] ?? '',
                                                style: TextStyle(
                                                  color: readerTheme.textColor
                                                      .withOpacity(0.7),
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Chapter ${int.parse(annotation['chapter'] ?? '0') + 1}',
                                                  style: TextStyle(
                                                    color: readerTheme.textColor
                                                        .withOpacity(0.5),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    controller.changeChapter(
                                                      int.parse(
                                                        annotation['chapter'] ??
                                                            '0',
                                                      ),
                                                    );

                                                    // Jump to position if available
                                                    WidgetsBinding.instance.addPostFrameCallback((
                                                      _,
                                                    ) {
                                                      if (_scrollController
                                                              .hasClients &&
                                                          annotation['position'] !=
                                                              null) {
                                                        final position =
                                                            double.parse(
                                                              annotation['position']
                                                                  .toString(),
                                                            );
                                                        final scrollTo =
                                                            _scrollController
                                                                .position
                                                                .maxScrollExtent *
                                                            (position / 100);
                                                        _scrollController.animateTo(
                                                          scrollTo.clamp(
                                                            0,
                                                            _scrollController
                                                                .position
                                                                .maxScrollExtent,
                                                          ),
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    300,
                                                              ),
                                                          curve: Curves.easeOut,
                                                        );
                                                      }
                                                    });

                                                    Get.back();
                                                  },
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  child: Text(
                                                    'Go to',
                                                    style: TextStyle(
                                                      color:
                                                          readerTheme
                                                              .accentColor,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                          // Highlights Tab
                          controller.highlights.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.highlight_alt,
                                      color: readerTheme.textColor.withOpacity(
                                        0.5,
                                      ),
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No highlights yet',
                                      style: TextStyle(
                                        color: readerTheme.textColor
                                            .withOpacity(0.7),
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Long-press text and select "Highlight" to add',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: readerTheme.textColor
                                            .withOpacity(0.5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                itemCount: controller.highlights.length,
                                itemBuilder: (context, index) {
                                  final highlight =
                                      controller.highlights[index];
                                  return Dismissible(
                                    key: Key('highlight_$index'),
                                    background: Container(
                                      color: Colors.red.withOpacity(0.5),
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    direction: DismissDirection.endToStart,
                                    onDismissed: (_) {
                                      controller.removeHighlight(highlight);
                                      _showSuccessSnackbar('Highlight removed');
                                    },
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      color: Colors.amber.withOpacity(0.1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.format_quote,
                                                  color: Colors.amber.shade700,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    highlight,
                                                    style: TextStyle(
                                                      color:
                                                          readerTheme.textColor,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                TextButton.icon(
                                                  icon: Icon(
                                                    Icons.share,
                                                    size: 16,
                                                  ),
                                                  label: Text('Share'),
                                                  onPressed: () {
                                                    final bookTitle =
                                                        controller
                                                            .epubBook
                                                            ?.Title ??
                                                        'my book';
                                                    Share.share(
                                                      '"$highlight" - from $bookTitle',
                                                      subject:
                                                          'Quote from $bookTitle',
                                                    );
                                                  },
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    foregroundColor:
                                                        readerTheme.accentColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareBook() {
    final readerTheme = AppTheme.readerThemes[controller.currentTheme.value]!;
    final bookTitle = controller.epubBook?.Title ?? 'book';

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: readerTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: readerTheme.textColor,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  icon: Icons.link,
                  label: 'Book Link',
                  onTap: () {
                    Get.back();
                    Share.share(
                      'Check out "$bookTitle" that I\'m reading!',
                      subject: 'Book Recommendation: $bookTitle',
                    );
                  },
                  theme: readerTheme,
                ),
                _buildShareOption(
                  icon: Icons.content_copy,
                  label: 'Current Page',
                  onTap: () {
                    final chapter =
                        controller.epubBook?.Chapters?[controller
                            .currentChapter
                            .value];
                    if (chapter != null) {
                      final chapterTitle =
                          chapter.Title ??
                          'Chapter ${controller.currentChapter.value + 1}';
                      Get.back();
                      Share.share(
                        'I\'m reading "$chapterTitle" from "$bookTitle".',
                        subject: 'Reading: $bookTitle',
                      );
                    }
                  },
                  theme: readerTheme,
                ),
                _buildShareOption(
                  icon: Icons.bar_chart,
                  label: 'Progress',
                  onTap: () {
                    final progress = controller.readingStats['progress'] ?? '0';
                    Get.back();
                    Share.share(
                      'I\'m $progress% through "$bookTitle"!',
                      subject: 'Reading Progress: $bookTitle',
                    );
                  },
                  theme: readerTheme,
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'Cancel',
                style: TextStyle(color: readerTheme.accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ReaderTheme theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: theme.accentColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: theme.textColor, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final readerTheme = AppTheme.readerThemes[controller.currentTheme.value]!;
      _updateSystemUI();

      return Scaffold(
        backgroundColor: readerTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: readerTheme.backgroundColor,
          elevation: 0,
          leading: BackButton(color: readerTheme.textColor),
          title: Text(
            controller.epubBook?.Title ?? 'Reading',
            style: TextStyle(color: readerTheme.textColor),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            _buildAnimatedIcon(Icons.search, 'Search', _showSearchDialog),
            _buildAnimatedIcon(
              Icons.bookmark_add,
              'Add Bookmark',
              _addBookmark,
            ),
            _buildAnimatedIcon(
              Icons.settings,
              'Reading Settings',
              _showReadingOptionsDialog,
            ),
            PopupMenuButton(
              icon: Icon(Icons.more_vert, color: readerTheme.textColor),
              color: readerTheme.backgroundColor,
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'toc',
                      child: Row(
                        children: [
                          Icon(
                            Icons.list,
                            color: readerTheme.textColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Table of Contents',
                            style: TextStyle(color: readerTheme.textColor),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'bookmarks',
                      child: Row(
                        children: [
                          Icon(
                            Icons.bookmarks,
                            color: readerTheme.textColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Bookmarks',
                            style: TextStyle(color: readerTheme.textColor),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'notes',
                      child: Row(
                        children: [
                          Icon(
                            Icons.note_alt,
                            color: readerTheme.textColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Notes & Highlights',
                            style: TextStyle(color: readerTheme.textColor),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'stats',
                      child: Row(
                        children: [
                          Icon(
                            Icons.bar_chart,
                            color: readerTheme.textColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reading Statistics',
                            style: TextStyle(color: readerTheme.textColor),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(
                            Icons.share,
                            color: readerTheme.textColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Share',
                            style: TextStyle(color: readerTheme.textColor),
                          ),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                switch (value) {
                  case 'toc':
                    _showTableOfContents();
                    break;
                  case 'bookmarks':
                    _showBookmarksDialog();
                    break;
                  case 'notes':
                    _showAnnotationsDialog();
                    break;
                  case 'stats':
                    _showStatsDialog();
                    break;
                  case 'share':
                    _shareBook();
                    break;
                }
              },
            ),
          ],
        ),
        body:
            controller.isLoading.value
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: readerTheme.accentColor),
                      const SizedBox(height: 16),
                      Text(
                        'Loading book...',
                        style: TextStyle(color: readerTheme.textColor),
                      ),
                    ],
                  ),
                )
                : GestureDetector(
                  onHorizontalDragStart: (details) {
                    _startDragX = details.globalPosition.dx;
                    _isDragging = true;
                  },
                  onHorizontalDragUpdate: (details) {
                    if (!_isDragging) return;

                    final currentX = details.globalPosition.dx;
                    final diff = currentX - _startDragX;

                    // If dragged far enough, change chapter
                    if (diff.abs() > 100) {
                      _isDragging = false;
                      if (diff > 0) {
                        // Right swipe - previous chapter
                        if (controller.currentChapter.value > 0) {
                          controller.changeChapter(
                            controller.currentChapter.value - 1,
                          );
                          _animationController.forward(from: 0);
                        }
                      } else {
                        // Left swipe - next chapter
                        if (controller.epubBook != null &&
                            controller.currentChapter.value <
                                (controller.epubBook!.Chapters?.length ?? 0) -
                                    1) {
                          controller.changeChapter(
                            controller.currentChapter.value + 1,
                          );
                          _animationController.forward(from: 0);
                        }
                      }
                    }
                  },
                  onHorizontalDragEnd: (details) {
                    _isDragging = false;
                  },
                  child: Stack(
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child:
                            controller.epubBook == null
                                ? Center(
                                  child: CircularProgressIndicator(
                                    color: readerTheme.accentColor,
                                  ),
                                )
                                : PageView.builder(
                                  itemCount:
                                      controller.epubBook!.Chapters?.length ??
                                      0,
                                  controller: PageController(
                                    initialPage:
                                        controller.currentChapter.value,
                                  ),
                                  onPageChanged: (index) {
                                    controller.changeChapter(index);
                                    _animationController.forward(from: 0);
                                    HapticFeedback.mediumImpact();
                                  },
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    if (controller.epubBook?.Chapters == null ||
                                        index >=
                                            controller
                                                .epubBook!
                                                .Chapters!
                                                .length) {
                                      return const Center(
                                        child: Text('Chapter not available'),
                                      );
                                    }

                                    final chapter =
                                        controller.epubBook!.Chapters![index];
                                    final plainText = controller.getPlainText(
                                      chapter.HtmlContent ?? '',
                                    );

                                    return Semantics(
                                      label:
                                          'Chapter ${index + 1}: ${chapter.Title ?? ''}',
                                      hint:
                                          'Swipe left or right to change chapters',
                                      child: SingleChildScrollView(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.all(20),
                                        child: Container(
                                          margin: const EdgeInsets.all(8),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: readerTheme.backgroundColor,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.05,
                                                ),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (chapter.Title != null &&
                                                  chapter.Title!.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 16.0,
                                                      ),
                                                  child: Text(
                                                    chapter.Title!,
                                                    style: TextStyle(
                                                      fontSize:
                                                          controller
                                                              .fontSize
                                                              .value *
                                                          1.2,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          readerTheme.textColor,
                                                      fontFamily:
                                                          controller
                                                              .fontFamily
                                                              .value,
                                                    ),
                                                  ),
                                                ),
                                              SelectableText(
                                                plainText,
                                                style: TextStyle(
                                                  fontSize:
                                                      controller.fontSize.value,
                                                  color: readerTheme.textColor,
                                                  height:
                                                      controller
                                                          .lineHeight
                                                          .value,
                                                  fontFamily:
                                                      controller
                                                          .fontFamily
                                                          .value,
                                                ),
                                                onSelectionChanged: (
                                                  selection,
                                                  cause,
                                                ) {
                                                  if (selection.isValid &&
                                                      cause ==
                                                          SelectionChangedCause
                                                              .longPress) {
                                                    final selectedText =
                                                        plainText.substring(
                                                          selection.start,
                                                          selection.end,
                                                        );
                                                    final position =
                                                        selection.start /
                                                        plainText.length *
                                                        100;
                                                    _showSelectionDialog(
                                                      selectedText,
                                                      position,
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),

                      // Reading progress indicator
                      if (controller.showPageNumbers.value &&
                          !controller.isLoading.value)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            color: readerTheme.backgroundColor.withOpacity(0.8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: LinearProgressIndicator(
                                    value:
                                        double.tryParse(
                                                  controller
                                                          .readingStats['progress'] ??
                                                      '0',
                                                ) !=
                                                null
                                            ? double.parse(
                                                  controller
                                                      .readingStats['progress']!,
                                                ) /
                                                100
                                            : 0,
                                    backgroundColor: readerTheme.textColor
                                        .withOpacity(0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      readerTheme.accentColor,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                    minHeight: 4,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 16,
                                    right: 16,
                                    bottom: 8,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Chapter ${controller.currentChapter.value + 1}/${controller.epubBook?.Chapters?.length ?? 0}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: readerTheme.textColor
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                      Text(
                                        '${controller.readingStats['progress'] ?? "0"}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: readerTheme.textColor
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

        // Bottom Navigation Buttons
        bottomNavigationBar:
            controller.isLoading.value
                ? null
                : Container(
                  color: readerTheme.backgroundColor,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavButton(
                            icon: Icons.arrow_back_ios,
                            label: 'Previous',
                            onPressed:
                                controller.currentChapter.value > 0
                                    ? () {
                                      controller.changeChapter(
                                        controller.currentChapter.value - 1,
                                      );
                                      _animationController.forward(from: 0);
                                      HapticFeedback.mediumImpact();
                                    }
                                    : null,
                            theme: readerTheme,
                          ),
                          _buildNavButton(
                            icon: Icons.list,
                            label: 'Contents',
                            onPressed: _showTableOfContents,
                            theme: readerTheme,
                          ),
                          _buildNavButton(
                            icon:
                                controller.isSpeaking
                                    ? Icons.stop
                                    : Icons.volume_up,
                            label:
                                controller.isSpeaking
                                    ? 'Stop Reading'
                                    : 'Read Aloud',
                            onPressed:
                                controller.isVoiceoverEnabled.value
                                    ? () {
                                      if (controller.isSpeaking) {
                                        controller.stopReading();
                                      } else {
                                        final chapter =
                                            controller
                                                .epubBook!
                                                .Chapters![controller
                                                .currentChapter
                                                .value];
                                        final plainText = controller
                                            .getPlainText(
                                              chapter.HtmlContent ?? '',
                                            );
                                        controller.startReading(plainText);
                                      }
                                    }
                                    : null,
                            theme: readerTheme,
                          ),
                          _buildNavButton(
                            icon: Icons.arrow_forward_ios,
                            label: 'Next',
                            onPressed:
                                controller.epubBook != null &&
                                        controller.currentChapter.value <
                                            (controller
                                                        .epubBook!
                                                        .Chapters
                                                        ?.length ??
                                                    0) -
                                                1
                                    ? () {
                                      controller.changeChapter(
                                        controller.currentChapter.value + 1,
                                      );
                                      _animationController.forward(from: 0);
                                      HapticFeedback.mediumImpact();
                                    }
                                    : null,
                            theme: readerTheme,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      );
    });
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required ReaderTheme theme,
  }) {
    final isDisabled = onPressed == null;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        enabled: !isDisabled,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Icon(
              icon,
              color:
                  isDisabled
                      ? theme.textColor.withOpacity(0.3)
                      : theme.textColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  void _showSearchDialog() {
    final TextEditingController searchController = TextEditingController();
    final readerTheme = AppTheme.readerThemes[controller.currentTheme.value]!;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: readerTheme.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Search Book',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: readerTheme.textColor,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                style: TextStyle(color: readerTheme.textColor),
                decoration: InputDecoration(
                  hintText: 'Enter search term',
                  hintStyle: TextStyle(
                    color: readerTheme.textColor.withOpacity(0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: readerTheme.textColor.withOpacity(0.7),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: readerTheme.textColor.withOpacity(0.05),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: readerTheme.accentColor),
                  ),
                ),
                onSubmitted: (_) => _performSearch(searchController.text),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: readerTheme.accentColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _performSearch(searchController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: readerTheme.accentColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Search'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _performSearch(String query) {
    final results = controller.searchBook(query);
    if (results != null && results.isNotEmpty) {
      final index = controller.epubBook!.Chapters!.indexOf(results.first);
      controller.changeChapter(index);
      Get.back();
    } else {
      Get.snackbar(
        'No Results',
        'No matches found for "$query"',
        backgroundColor: Colors.red.withOpacity(0.7),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  void _addBookmark() {
    if (controller.epubBook == null) return;

    final chapter =
        controller.epubBook!.Chapters![controller.currentChapter.value];
    controller.addBookmark(
      chapter.Title ?? 'Chapter ${controller.currentChapter.value + 1}',
      controller.readingPosition.value,
    );

    _showSuccessSnackbar('Bookmark added');
  }

  void _showTableOfContents() {
    if (controller.epubBook == null) return;

    final readerTheme = AppTheme.readerThemes[controller.currentTheme.value]!;

    Get.bottomSheet(
      Container(
        height: Get.height * 0.7,
        decoration: BoxDecoration(
          color: readerTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: readerTheme.textColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Table of Contents',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: readerTheme.textColor,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: controller.epubBook!.Chapters?.length ?? 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final chapter = controller.epubBook!.Chapters![index];
                  final isCurrentChapter =
                      index == controller.currentChapter.value;

                  return Semantics(
                    button: true,
                    label:
                        'Chapter ${index + 1}: ${chapter.Title ?? 'Untitled'}',
                    selected: isCurrentChapter,
                    child: Card(
                      color:
                          isCurrentChapter
                              ? readerTheme.accentColor.withOpacity(0.1)
                              : readerTheme.backgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color:
                              isCurrentChapter
                                  ? readerTheme.accentColor
                                  : readerTheme.textColor.withOpacity(0.1),
                          width: isCurrentChapter ? 1 : 0.5,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          controller.changeChapter(index);
                          Get.back();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Text(
                                '${index + 1}.',
                                style: TextStyle(
                                  color:
                                      isCurrentChapter
                                          ? readerTheme.accentColor
                                          : readerTheme.textColor.withOpacity(
                                            0.7,
                                          ),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  chapter.Title ?? 'Chapter ${index + 1}',
                                  style: TextStyle(
                                    color:
                                        isCurrentChapter
                                            ? readerTheme.accentColor
                                            : readerTheme.textColor,
                                    fontWeight:
                                        isCurrentChapter
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isCurrentChapter)
                                Icon(
                                  Icons.bookmark,
                                  color: readerTheme.accentColor,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _showStatsDialog() {
    final readerTheme = AppTheme.readerThemes[controller.currentTheme.value]!;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: readerTheme.backgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Reading Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: readerTheme.textColor,
                ),
              ),
              const SizedBox(height: 20),
              _buildStatItem(
                icon: Icons.auto_stories,
                label: 'Chapters Read',
                value:
                    '${controller.readingStats['chaptersRead'] ?? 0} of ${controller.readingStats['totalChapters'] ?? 0}',
                theme: readerTheme,
              ),
              _buildStatItem(
                icon: Icons.percent,
                label: 'Progress',
                value: '${controller.readingStats['progress'] ?? "0"}%',
                theme: readerTheme,
              ),
              _buildStatItem(
                icon: Icons.access_time,
                label: 'Reading Time',
                value: '${controller.readingStats['totalTime'] ?? 0} minutes',
                theme: readerTheme,
              ),
              _buildStatItem(
                icon: Icons.calendar_today,
                label: 'Last Read',
                value:
                    controller.readingStats['lastRead'] != null
                        ? controller.readingStats['lastRead']!.toString().split(
                          ' ',
                        )[0]
                        : 'Today',
                theme: readerTheme,
              ),
              _buildStatItem(
                icon: Icons.note_alt,
                label: 'Annotations',
                value: '${controller.annotations.length}',
                theme: readerTheme,
              ),
              _buildStatItem(
                icon: Icons.bookmarks,
                label: 'Bookmarks',
                value: '${controller.bookmarks.length}',
                theme: readerTheme,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: readerTheme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
