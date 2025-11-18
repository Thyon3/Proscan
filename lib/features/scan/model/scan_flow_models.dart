import 'package:flutter/material.dart';

enum ScanMode {
  slides,
  excel,
  timestamp,
  extractText,
  word,
  document,
  idCard,
  question,
  translate,
  book;

  String get name => switch (this) {
    slides => 'Slides',
    excel => 'Excel',
    timestamp => 'Timestamp',
    extractText => 'Extract Text',
    word => 'Word',
    document => 'Scan',
    idCard => 'ID Card',
    question => 'Question',
    translate => 'Translate',
    book => 'Book',
  };

  IconData get icon => switch (this) {
    slides => Icons.slideshow_rounded,
    excel => Icons.grid_on_rounded,
    timestamp => Icons.schedule_rounded,
    extractText => Icons.text_snippet_rounded,
    word => Icons.text_fields_rounded,
    document => Icons.document_scanner_rounded,
    idCard => Icons.credit_card_rounded,
    question => Icons.quiz_rounded,
    translate => Icons.translate_rounded,
    book => Icons.menu_book_rounded,
  };

  String get hint => switch (this) {
    slides => 'Capture slide fully',
    excel => 'Align table with grid',
    timestamp => 'Include date/time',
    extractText => 'Capture any text',
    word => 'Place page flat',
    document => 'Align document within frame',
    idCard => 'Center ID card perfectly',
    question => 'Capture question clearly',
    translate => 'Point at text to translate',
    book => 'Open book flat, avoid shadows',
  };

  bool get showGrid => this == ScanMode.excel || this == ScanMode.slides;
  bool get showIdFrame => this == ScanMode.idCard;
  bool get autoDewarpHint => this == ScanMode.book || this == ScanMode.document;
}

class EditScanArgs {
  final String imagePath;
  final ScanMode initialMode;

  const EditScanArgs({required this.imagePath, required this.initialMode});
}

class CameraScreenConfig {
  final ScanMode initialMode;
  final bool restrictToInitialMode;
  final bool returnCapturePath;

  const CameraScreenConfig({
    this.initialMode = ScanMode.document,
    this.restrictToInitialMode = false,
    this.returnCapturePath = false,
  });
}
