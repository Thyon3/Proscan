// GENERATED CODE - DO NOT MODIFY BY HAND
// This file was generated manually due to dependency conflicts with hive_generator

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
      scanMode: fields[8] == null ? 'document' : fields[8] as String,
      textContent: fields[9] == null ? '' : fields[9] as String?,
      updatedAt: fields[10] as DateTime,
      colorProfile: fields[11] == null ? 'color' : fields[11] as String,
      pageImagePaths: fields[7] == null ? <String>[] : (fields[7] as List?)?.cast<String>(),
      tags: fields[12] == null ? <String>[] : (fields[12] as List?)?.cast<String>(),
      metadata: fields[13] == null ? <String, String>{} : (fields[13] as Map?)?.cast<String, String>(),
      isDeleted: fields[14] == null ? false : fields[14] as bool,
      deletedAt: fields[15] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DocumentModel obj) {
    writer
      ..writeByte(16)
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
      ..write(obj._pageImagePaths)
      ..writeByte(8)
      ..write(obj.scanMode)
      ..writeByte(9)
      ..write(obj.textContent)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.colorProfile)
      ..writeByte(12)
      ..write(obj._tags)
      ..writeByte(13)
      ..write(obj._metadata)
      ..writeByte(14)
      ..write(obj.isDeleted)
      ..writeByte(15)
      ..write(obj.deletedAt);
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

