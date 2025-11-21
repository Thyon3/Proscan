import 'package:hive/hive.dart';

/// Represents a saved scanned document (PDF only).
///
/// Stored in Hive inside an encrypted box with UUID string keys.
/// Uses manual TypeAdapter - no build_runner needed.
@HiveType(typeId: 0)
class DocumentModel extends HiveObject {
  /// Unique identifier (UUID v4 string).
  @HiveField(0)
  final String id;

  /// User-editable title (e.g., "Scan Nov 21, 2025").
  @HiveField(1)
  String title;

  /// Absolute file path of the exported PDF document.
  @HiveField(2)
  final String filePath;

  /// Format - always 'pdf' in this version.
  @HiveField(3)
  final String format;

  /// Creation timestamp.
  @HiveField(4)
  final DateTime createdAt;

  /// Number of pages in the scan.
  @HiveField(5)
  final int pageCount;

  /// Absolute file path to the thumbnail image (first page).
  @HiveField(6)
  final String thumbnailPath;

  DocumentModel({
    required this.id,
    required this.title,
    required this.filePath,
    required this.format,
    required this.createdAt,
    required this.pageCount,
    required this.thumbnailPath,
  });
}

/// Manual Hive adapter - no code generation required.
/// Handles serialization/deserialization of DocumentModel.
class DocumentModelAdapter extends TypeAdapter<DocumentModel> {
  @override
  final int typeId = 0;

  @override
  DocumentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return DocumentModel(
      id: fields[0] as String,
      title: fields[1] as String,
      filePath: fields[2] as String,
      format: fields[3] as String,
      createdAt: fields[4] as DateTime,
      pageCount: fields[5] as int,
      thumbnailPath: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DocumentModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.format)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.pageCount)
      ..writeByte(6)
      ..write(obj.thumbnailPath);
  }
}
