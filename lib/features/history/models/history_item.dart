class HistoryItem {
  final String id;
  final String toolName;
  final String title;
  final String subtitle;
  final List<String> filePaths;
  final int originalBytes;
  final int outputBytes;
  final DateTime timestamp;

  const HistoryItem({
    required this.id,
    required this.toolName,
    required this.title,
    required this.subtitle,
    required this.filePaths,
    this.originalBytes = 0,
    this.outputBytes = 0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'toolName': toolName,
        'title': title,
        'subtitle': subtitle,
        'filePaths': filePaths,
        'originalBytes': originalBytes,
        'outputBytes': outputBytes,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String,
        toolName: json['toolName'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        filePaths: (json['filePaths'] as List<dynamic>).map((e) => e as String).toList(),
        originalBytes: json['originalBytes'] as int? ?? 0,
        outputBytes: json['outputBytes'] as int? ?? 0,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
