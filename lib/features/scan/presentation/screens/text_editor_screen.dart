// features/scan/presentation/screens/text_editor_screen.dart
import 'dart:io';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/features/scan/core/services/file_export_service.dart';
import 'package:thyscan/features/scan/core/services/ocr_service.dart';
import 'package:thyscan/services/document_service.dart';

class TextEditorScreen extends StatefulWidget {
  final String extractedText;
  final String? imagePath;

  const TextEditorScreen({
    super.key,
    required this.extractedText,
    this.imagePath,
  });

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late TextEditingController _textController;
  final FileExportService _fileExportService = FileExportService();
  final OcrService _ocrService = OcrService();
  bool _isExporting = false;
  bool _isProcessing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.extractedText);
    
    // If imagePath is provided but no extractedText, process OCR
    if (widget.imagePath != null && widget.extractedText.isEmpty) {
      _processOcr();
    } else {
      // Auto-focus the text field for better UX
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  Future<void> _processOcr() async {
    if (widget.imagePath == null) return;

    setState(() => _isProcessing = true);

    try {
      final extractedText = await _ocrService.extractTextFromImage(widget.imagePath!);
      
      if (mounted) {
        if (extractedText == null || extractedText.isEmpty) {
          _showSnackBar('No text found in the image', isError: true);
          // Still allow user to type manually
          _textController.clear();
        } else {
          _textController.text = extractedText;
        }
        
        // Auto-focus after processing
        _focusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to extract text: $e', isError: true);
        // Allow user to type manually even if OCR fails
        _textController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard() async {
    try {
      final text = _textController.text.trim();
      if (text.isEmpty) {
        _showSnackBar('No text to copy', isError: true);
        return;
      }

      await FlutterClipboard.copy(text);
      _showSnackBar('Text copied to clipboard');
    } catch (e) {
      _showSnackBar('Failed to copy text: $e', isError: true);
    }
  }

  Future<void> _exportToWord() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('No text to export', isError: true);
      return;
    }

    setState(() => _isExporting = true);

    try {
      // Save Word document to Hive and internal storage
      final doc = await DocumentService.instance.saveTextDocument(
        text: text,
        title: 'Extracted Text ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
      );

      if (mounted) {
        _showSnackBar('Word document saved successfully');
        
        // Redirect to home screen
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.go('/appmainscreen'); // Navigate to main app screen (home)
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to export: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Extracted Text',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.copy_rounded, color: cs.primary),
            tooltip: 'Copy',
            onPressed: _copyToClipboard,
          ),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Extracting text from image...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Text editor area
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 1.5,
                          color: cs.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Edit extracted text here...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 16,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(8),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom action bar
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Copy button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _copyToClipboard,
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copy'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Export to Word button
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _isExporting ? null : _exportToWord,
                              icon: _isExporting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.description_rounded),
                              label: Text(_isExporting ? 'Exporting...' : 'Export to Word'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

