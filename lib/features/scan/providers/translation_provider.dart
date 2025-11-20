import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// REMOVED: import 'package:flutter_riverpod/legacy.dart' show StateNotifierProvider, StateNotifier;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:thyscan/features/scan/services/export_service.dart';
import 'package:thyscan/features/scan/services/ocr_service.dart';
import 'package:thyscan/features/scan/services/translation_service.dart';

/// Supported target languages for translation.
enum SupportedLanguage {
  english('en', 'English'),
  spanish('es', 'Spanish'),
  french('fr', 'French'),
  german('de', 'German'),
  italian('it', 'Italian'),
  portuguese('pt', 'Portuguese');

  const SupportedLanguage(this.code, this.label);

  final String code;
  final String label;
}

/// Immutable state for translate mode.
class TranslationState {
  const TranslationState({
    this.sourceText = '',
    this.translatedText = '',
    this.sourceLanguageCode = 'auto',
    this.targetLanguage = SupportedLanguage.english,
    this.isLoading = false,
    this.errorMessage,
  });

  final String sourceText;
  final String translatedText;
  final String sourceLanguageCode;
  final SupportedLanguage targetLanguage;
  final bool isLoading;
  final String? errorMessage;

  bool get hasText => sourceText.trim().isNotEmpty;

  TranslationState copyWith({
    String? sourceText,
    String? translatedText,
    String? sourceLanguageCode,
    SupportedLanguage? targetLanguage,
    bool? isLoading,
    String? errorMessage,
  }) {
    return TranslationState(
      sourceText: sourceText ?? this.sourceText,
      translatedText: translatedText ?? this.translatedText,
      sourceLanguageCode: sourceLanguageCode ?? this.sourceLanguageCode,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Provider for the shared [TranslationService] instance.
final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService();
});

/// Riverpod Notifier managing OCR + translation + export for Translate mode.
// 🟢 MIGRATED: Inherit from Notifier
class TranslationController extends Notifier<TranslationState> {
  // 🟢 MIGRATED: Dependencies are read in build() and stored here
  late final TranslateOcrService _ocrService;
  late final TranslationService _translationService;
  late final ExportService _exportService;

  // 🟢 MIGRATED: Replaces the constructor and returns the initial state.
  // This is where dependencies are initialized using ref.watch/read.
  @override
  TranslationState build() {
    // Get dependencies using the exposed 'ref' property
    _translationService = ref.watch(translationServiceProvider);
    // These services are created here and stored for later use.
    _ocrService = TranslateOcrService();
    _exportService = ExportService();

    // Return the initial state
    // Note: 'ref' is now a class property, eliminating the need to pass it around.
    ref.onDispose(() {
      _ocrService.dispose();
    });

    return const TranslationState();
  }

  /// Runs OCR + translation on [inputImage].
  ///
  /// This is intended to be called from the camera flow for Translate mode.
  Future<void> processInputImage(InputImage inputImage) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final ocrText = await _ocrService.extractText(inputImage);

      if (ocrText == null || ocrText.trim().isEmpty) {
        state = state.copyWith(
          sourceText: '',
          translatedText: '',
          isLoading: false,
          errorMessage: 'No readable text detected in the image.',
        );
        return;
      }

      state = state.copyWith(sourceText: ocrText, errorMessage: null);

      final translated = await _translationService.translateSafe(
        text: ocrText,
        from: state.sourceLanguageCode,
        to: state.targetLanguage.code,
      );

      state = state.copyWith(
        translatedText: translated,
        isLoading: false,
        errorMessage: null,
      );
    } on TranslationFailure catch (e) {
      state = state.copyWith(
        isLoading: false,
        translatedText: '',
        errorMessage: e.message,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        translatedText: '',
        errorMessage: 'Unexpected error while processing image: $e',
      );
    }
  }

  /// Updates the in‑memory translated text when the user edits it.
  void updateTranslatedText(String value) {
    state = state.copyWith(translatedText: value, errorMessage: null);
  }

  /// Updates the in‑memory source text (in case you expose editing source).
  void updateSourceText(String value) {
    state = state.copyWith(sourceText: value, errorMessage: null);
  }

  /// Changes the target language and re‑translates the existing source text.
  Future<void> changeTargetLanguage(SupportedLanguage language) async {
    if (!state.hasText) {
      state = state.copyWith(targetLanguage: language);
      return;
    }

    state = state.copyWith(
      targetLanguage: language,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final translated = await _translationService.translateSafe(
        text: state.sourceText,
        from: state.sourceLanguageCode,
        to: language.code,
      );

      state = state.copyWith(translatedText: translated, isLoading: false);
    } on TranslationFailure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unexpected error while re‑translating: $e',
      );
    }
  }

  /// Explicit re‑translate using current target language.
  Future<void> retranslate() async {
    await changeTargetLanguage(state.targetLanguage);
  }

  /// Exports the current translated text as PDF in a temp directory.
  ///
  /// Returns the created [File], or `null` if there is no text.
  Future<File?> exportAsPdf({String? fileName}) async {
    final text = state.translatedText.trim();
    if (text.isEmpty) return null;

    try {
      final file = await _exportService.exportToPdf(
        content: text,
        fileName: fileName,
      );
      return file;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to export PDF: $e');
      return null;
    }
  }

  /// Exports the current translated text as DOCX in a temp directory.
  ///
  /// Returns the created [File], or `null` if there is no text.
  Future<File?> exportAsDocx({String? fileName}) async {
    final text = state.translatedText.trim();
    if (text.isEmpty) return null;

    try {
      final file = await _exportService.exportToDocx(
        content: text,
        fileName: fileName,
      );
      return file;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to export Word document: $e',
      );
      return null;
    }
  }

  // in the build() method.
}

/// Global provider for Translate mode.
// 🟢 MIGRATED: Use NotifierProvider and the constructor tear-off
final translationProvider =
    NotifierProvider<TranslationController, TranslationState>(
      TranslationController.new,
    );
