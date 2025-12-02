// features/scan/presentation/screens/text_editor_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:thyscan/core/services/app_logger.dart';
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
  late FocusNode _focusNode;
  final FileExportService _fileExportService = FileExportService();
  final OcrService _ocrService = OcrService();
  
  bool _isExporting = false;
  bool _isProcessing = false;
  bool _hasUnsavedChanges = false;
  Timer? _debounceTimer;
  String? _lastSavedText;

  int get _characterCount => _textController.text.length;
  int get _wordCount {
    final text = _textController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.extractedText);
    _focusNode = FocusNode();
    _lastSavedText = widget.extractedText;
    
    _textController.addListener(_onTextChanged);
    
    // If imagePath is provided but no extractedText, process OCR
    if (widget.imagePath != null && widget.extractedText.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _processOcr());
    } else {
      // Auto-focus the text field for better UX
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  void _onTextChanged() {
    setState(() {
      _hasUnsavedChanges = _textController.text != _lastSavedText;
    });
  }

  Future<void> _processOcr() async {
    if (widget.imagePath == null) return;

    setState(() => _isProcessing = true);

    try {
      AppLogger.info('Starting OCR extraction', data: {'path': widget.imagePath});
      final extractedText = await _ocrService.extractTextFromImage(widget.imagePath!);
      
      if (mounted) {
        if (extractedText == null || extractedText.isEmpty) {
          _showSnackBar(
            'No text found in the image. You can type manually.',
            isError: true,
          );
          _textController.clear();
        } else {
          _textController.text = extractedText;
          _lastSavedText = extractedText;
          _hasUnsavedChanges = false;
          _showSnackBar('Text extracted successfully!');
        }
        
        // Auto-focus after processing
        _focusNode.requestFocus();
      }
    } catch (e, stackTrace) {
      AppLogger.error('OCR processing failed', error: e, stack: stackTrace);
      if (mounted) {
        _showSnackBar(
          'Failed to extract text: ${e.toString().split(':').last.trim()}',
          isError: true,
        );
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
    _debounceTimer?.cancel();
    _textController.removeListener(_onTextChanged);
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
      HapticFeedback.lightImpact();
      _showSnackBar('Text copied to clipboard');
    } catch (e) {
      AppLogger.error('Failed to copy text', error: e);
      _showSnackBar('Failed to copy text', isError: true);
    }
  }

  Future<void> _exportToWord() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _showSnackBar('No text to export', isError: true);
      return;
    }

    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();

    try {
      final doc = await DocumentService.instance.saveTextDocument(
        text: text,
        title: 'Extracted Text ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
      );

      if (mounted) {
        _showSnackBar(
          'Document saved successfully!',
          duration: const Duration(seconds: 3),
        );
        
        // Update saved state
        setState(() {
          _lastSavedText = text;
          _hasUnsavedChanges = false;
        });
        
        // Navigate after short delay
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          context.go('/appmainscreen');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Export failed', error: e, stack: stackTrace);
      if (mounted) {
        _showSnackBar('Failed to export: ${e.toString().split(':').last.trim()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop || !_hasUnsavedChanges) return;
        
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (context) => _buildUnsavedChangesDialog(cs),
        ) ?? false;

        if (shouldDiscard && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
            onPressed: () => context.pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Text Editor',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              if (_isProcessing)
                Text(
                  'Extracting text...',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          actions: [
            // Word/Character count indicator
            if (!_isProcessing)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.text_fields, size: 14, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      '$_wordCount words',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            IconButton(
              icon: Icon(Icons.content_copy_rounded, color: cs.primary),
              tooltip: 'Copy',
              onPressed: _copyToClipboard,
            ),
          ],
        ),
        body: _isProcessing
            ? _buildProcessingView(cs)
            : _buildEditorView(cs),
      ),
    );
  }

  Widget _buildProcessingView(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Extracting text from image...',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorView(ColorScheme cs) {
    return Column(
      children: [
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            border: Border(
              bottom: BorderSide(
                color: cs.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildStatChip(
                cs,
                Icons.text_fields,
                '$_wordCount words',
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                cs,
                Icons.format_size,
                '$_characterCount chars',
              ),
              const Spacer(),
              if (_hasUnsavedChanges)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'Unsaved',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Text editor area
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? cs.primary.withValues(alpha: 0.3)
                    : cs.outline.withValues(alpha: 0.1),
                width: _focusNode.hasFocus ? 2 : 1,
              ),
              boxShadow: _focusNode.hasFocus
                  ? [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.1),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.6,
                  letterSpacing: 0.2,
                  color: cs.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: _textController.text.isEmpty
                      ? 'Edit extracted text here...\n\nTip: You can paste or type directly in this field.'
                      : null,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 16,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    height: 1.6,
                  ),
                  border: InputBorder.none,
                ),
                onTap: () {
                  setState(() {}); // Update focus state
                },
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
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Copy button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.content_copy_rounded, size: 20),
                      label: Text(
                        'Copy',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: cs.outline.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Export to Word button
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
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
                          : const Icon(Icons.description_rounded, size: 20),
                      label: Text(
                        _isExporting ? 'Saving...' : 'Save as Word',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
    );
  }

  Widget _buildStatChip(ColorScheme cs, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsavedChangesDialog(ColorScheme cs) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unsaved Changes',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Text(
        'You have unsaved changes. Are you sure you want to leave?',
        style: GoogleFonts.inter(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade600,
          ),
          child: Text(
            'Discard',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
