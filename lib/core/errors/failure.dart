class Failure {
  final String title;
  final String message;
  final dynamic cause;

  const Failure({
    required this.title,
    required this.message,
    this.cause,
  });

  @override
  String toString() => '$title: $message';
}
