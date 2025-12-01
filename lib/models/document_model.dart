// models/document_model.dart
import 'package:hive/hive.dart';
import 'package:thyscan/models/document_color_profile.dart';

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

  @HiveField(10)
  final DateTime updatedAt;

  @HiveField(11, defaultValue: 'color')
  final String colorProfile;

  @HiveField(12, defaultValue: <String>[])
  final List<String>? _tags;

  @HiveField(13, defaultValue: <String, String>{})
  final Map<String, String>? _metadata;

  // Public getter that guarantees non-null list
  List<String> get pageImagePaths => _pageImagePaths ?? [];
  DocumentColorProfile get colorProfileEnum =>
      DocumentColorProfile.fromKey(colorProfile);
  List<String> get tags => _tags ?? const [];
  Map<String, String> get metadata => _metadata ?? const {};

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
    required this.updatedAt,
    this.colorProfile = 'color',
    List<String>? pageImagePaths,
    List<String>? tags,
    Map<String, String>? metadata,
  }) : _pageImagePaths = pageImagePaths,
       _tags = tags,
       _metadata = metadata;
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
    DateTime? updatedAt,
    String? colorProfile,
    List<String>? tags,
    Map<String, String>? metadata,
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
      updatedAt: updatedAt ?? this.updatedAt,
      colorProfile: colorProfile ?? this.colorProfile,
      pageImagePaths: pageImagePaths ?? this.pageImagePaths,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }
}
