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

  @HiveField(9, defaultValue: '')
  final String? textContent; // For text/docx documents

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
    this.textContent,
    List<String>? pageImagePaths,
  }) : _pageImagePaths = pageImagePaths;
  DocumentModel copyWith({
    String? id,
    String? title,
    String? filePath,
    String? format,
    DateTime? createdAt,
    int? pageCount,
    String? thumbnailPath,
    String? scanMode,
    String? textContent,
    List<String>? pageImagePaths,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      createdAt: createdAt ?? this.createdAt,
      pageCount: pageCount ?? this.pageCount,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      scanMode: scanMode ?? this.scanMode,
      textContent: textContent ?? this.textContent,
      pageImagePaths: pageImagePaths ?? this.pageImagePaths,
    );
  }
}
