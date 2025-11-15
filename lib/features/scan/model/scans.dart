class Scan {
  final String title;
  final String imagePath;
  final String date;
  final String size;
  final String pageCount;
  final List<String> tags;

  const Scan({
    required this.title,
    required this.imagePath,
    required this.date,
    required this.size,
    required this.pageCount,
    required this.tags,
  });
}
