import 'package:hive/hive.dart';

part 'document_model.g.dart';

@HiveType(typeId: 0)
class DocumentModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final String filePath;

  @HiveField(3)
  final String thumbnailPath;

  @HiveField(4)
  final String format;

  @HiveField(5)
  final int pageCount;

  @HiveField(6)
  final DateTime createdAt;

  DocumentModel({
    required this.id,
    required this.title,
    required this.filePath,
    required this.thumbnailPath,
    required this.format,
    required this.pageCount,
    required this.createdAt,
  });
}
