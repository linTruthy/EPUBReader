class RecentBook {
  final String title;
  final String filePath;
  final String coverPath;
  final DateTime lastRead;
  final double progress;

  RecentBook({
    required this.title,
    required this.filePath,
    this.coverPath = '',
    required this.lastRead,
    required this.progress,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'filePath': filePath,
    'coverPath': coverPath,
    'lastRead': lastRead.toIso8601String(),
    'progress': progress,
  };

  factory RecentBook.fromJson(Map<String, dynamic> json) => RecentBook(
    title: json['title'],
    filePath: json['filePath'],
    coverPath: json['coverPath'] ?? '',
    lastRead: DateTime.parse(json['lastRead']),
    progress: json['progress'],
  );
}
