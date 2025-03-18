import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:myapp/widgets/animated_button.dart';
import 'package:myapp/controllers/home_controller.dart';
import 'package:myapp/models/recent_book.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final controller = Get.put(HomeController());

  Future<void> _pickEpubFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
        dialogTitle: 'Select an EPUB book to read',
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.single.path != null) {
        final path = result.files.single.path!;

        Get.to(
          () => ReaderScreen(filePath: path),
          transition: Transition.fadeIn,
          duration: const Duration(milliseconds: 500),
        )?.then((bookData) {
          if (bookData != null && bookData is Map<String, dynamic>) {
            controller.addRecentBook(
              RecentBook(
                title: bookData['title'] ?? 'Unknown Book',
                filePath: path,
                lastRead: DateTime.now(),
                progress: bookData['progress'] ?? 0.0,
              ),
            );
          }
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to open file: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Theme.of(context).colorScheme.error.withOpacity(0.8),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 8,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isDarkMode
                    ? [const Color(0xFF1E1E1E), const Color(0xFF121212)]
                    : [Colors.blueGrey.shade100, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top logo and title section
              Expanded(
                flex: 3,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App Icon with semantic label
                          Semantics(
                            label: 'EPUB Reader App Icon',
                            child: Icon(
                              Icons.book_rounded,
                              size: 80,
                              color: Theme.of(context).colorScheme.primary,
                              semanticLabel: 'Book icon',
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Animated Title with accessibility considerations
                          Semantics(
                            label: 'App Title',
                            child: Text(
                              'app_name'.tr,
                              style: Theme.of(
                                context,
                              ).textTheme.displayLarge?.copyWith(
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.1),
                                    offset: const Offset(1, 1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Subtitle with accessibility considerations
                          Semantics(
                            label: 'Welcome message',
                            child: Text(
                              'welcome'.tr,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          // Animated Button with accessibility
                          Semantics(
                            button: true,
                            label: 'Open EPUB file button',
                            hint: 'Opens file picker to select an EPUB book',
                            child: AnimatedButton(
                              onPressed: () => _pickEpubFile(context),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.file_open_rounded,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'open_file'.tr,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Recent books section
              Expanded(
                flex: 4,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            'recent_books'.tr,
                            style: Theme.of(context).textTheme.headlineSmall,
                            semanticsLabel: 'Recent Books Section',
                          ),
                        ),
                        Expanded(
                          child: Obx(() {
                            if (controller.isLoading.value) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (controller.recentBooks.isEmpty) {
                              return Center(
                                child: Text(
                                  'no_books'.tr,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: controller.recentBooks.length,
                              itemBuilder: (context, index) {
                                final book = controller.recentBooks[index];
                                return Semantics(
                                  button: true,
                                  label: 'Open ${book.title}',
                                  hint:
                                      'Last read on ${book.lastRead.toString().split(' ')[0]}',
                                  child: Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Get.to(
                                          () => ReaderScreen(
                                            filePath: book.filePath,
                                          ),
                                          transition: Transition.fadeIn,
                                          duration: const Duration(
                                            milliseconds: 500,
                                          ),
                                        )?.then((bookData) {
                                          if (bookData != null &&
                                              bookData
                                                  is Map<String, dynamic>) {
                                            controller.addRecentBook(
                                              RecentBook(
                                                title:
                                                    bookData['title'] ??
                                                    book.title,
                                                filePath: book.filePath,
                                                lastRead: DateTime.now(),
                                                progress:
                                                    bookData['progress'] ??
                                                    book.progress,
                                              ),
                                            );
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
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
                                                // Book cover or placeholder
                                                Container(
                                                  width: 60,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.book,
                                                    size: 30,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        book.title,
                                                        style:
                                                            Theme.of(context)
                                                                .textTheme
                                                                .titleLarge,
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        'Last read: ${book.lastRead.toString().split(' ')[0]}',
                                                        style:
                                                            Theme.of(context)
                                                                .textTheme
                                                                .bodySmall,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      LinearProgressIndicator(
                                                        value:
                                                            book.progress / 100,
                                                        backgroundColor:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${book.progress.toStringAsFixed(1)}% completed',
                                                        style:
                                                            Theme.of(context)
                                                                .textTheme
                                                                .bodySmall,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
