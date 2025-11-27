// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DocumentModelAdapter extends TypeAdapter<DocumentModel> {
  @override
  final int typeId = 0;

  @override
  DocumentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DocumentModel(
      id: fields[0] as String,
      title: fields[1] as String,
      filePath: fields[2] as String,
      format: fields[3] as String,
      createdAt: fields[4] as DateTime,
      pageCount: fields[5] as int,
      thumbnailPath: fields[6] as String,
      scanMode: fields[8] as String? ?? 'document',
      textContent: fields[9] as String?,
      updatedAt: (fields[10] as DateTime?) ?? fields[4] as DateTime,
      colorProfile: fields[11] as String? ?? 'color',
      pageImagePaths: (fields[7] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DocumentModel obj) {
    writer
      ..writeByte(12)
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
      ..write(obj.thumbnailPath)
      ..writeByte(7)
      ..write(obj.pageImagePaths)
      ..writeByte(8)
      ..write(obj.scanMode)
      ..writeByte(9)
      ..write(obj.textContent)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.colorProfile);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

