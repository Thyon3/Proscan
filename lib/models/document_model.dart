// models/document_model.dart
import 'package:hive/hive.dart';

part 'document_model.g.dart';

@HiveType(typeId: 0)
class DocumentModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String filePath;

  @HiveField(3)
  final String format;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final int pageCount;

  @HiveField(6)
  final String thumbnailPath;

  @HiveField(7, defaultValue: <String>[])
  final List<String>? _pageImagePaths; // Internal nullable field

  @HiveField(8, defaultValue: 'document')
  final String scanMode;

  // Public getter that guarantees non-null list
  List<String> get pageImagePaths => _pageImagePaths ?? [];

  DocumentModel({
    required this.id,
    required this.title,
    required this.filePath,
    required this.format,
    required this.createdAt,
    required this.pageCount,
    required this.thumbnailPath,
    this.scanMode = 'document',
    List<String>? pageImagePaths,
  }) : _pageImagePaths = pageImagePaths;
}
