import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/core/utils/share_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:thyscan/core/services/docx_generator_service.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

class TextDocumentScreen extends StatefulWidget {
  final String documentId;

  const TextDocumentScreen({
    super.key,
    required this.documentId,
  });

  @override
  State<TextDocumentScreen> createState() => _TextDocumentScreenState();
}

class _TextDocumentScreenState extends State<TextDocumentScreen> {
  late TextEditingController _textController;
  DocumentModel? _document;
  bool _isModified = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _loadDocument();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    try {
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      final doc = box.get(widget.documentId);

      if (doc != null && mounted) {
        setState(() {
          _document = doc;
          _textController.text = doc.textContent ?? '';
        });

        // Listen for text changes
        _textController.addListener(() {
          if (!_isModified) {
            setState(() => _isModified = true);
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load document: $e');
    }
  }

  Future<void> _saveDocument() async {
    if (_document == null || !_isModified) return;

    setState(() => _isSaving = true);

    try {
      // Update the document with new text content
      final updatedDoc = DocumentModel(
        id: _document!.id,
        title: _document!.title,
        filePath: _document!.filePath,
        format: _document!.format,
        createdAt: _document!.createdAt,
        updatedAt: DateTime.now(),
        pageCount: _document!.pageCount,
        thumbnailPath: _document!.thumbnailPath,
        scanMode: _document!.scanMode,
        textContent: _textController.text,
        pageImagePaths: _document!.pageImagePaths,
        colorProfile: _document!.colorProfile,
      );

      // Save to Hive
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      await box.put(widget.documentId, updatedDoc);

      // Update the text file
      final file = File(_document!.filePath);
      await file.writeAsString(_textController.text);

      if (mounted) {
        setState(() {
          _document = updatedDoc;
          _isModified = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to home screen after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            // Use GoRouter to navigate to the main app screen (with bottom nav)
            // This ensures we don't get stuck in a sub-route or the standalone home screen
            context.go('/appmainscreen');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _exportToWord() async {
    if (_document == null) return;

    try {
      // Save the document first if there are unsaved changes
      if (_isModified) {
        await _saveDocument();
      }

      final docxPath = await DocxGeneratorService.instance.generateDocxFromText(
        text: _textController.text,
        title: _document!.title,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: ${docxPath.split('/').last}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () => _shareFile(docxPath),
            ),
          ),
        );

        // Navigate to home screen after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            // Use GoRouter to navigate to the main app screen (with bottom nav)
            // This ensures we don't get stuck in a sub-route or the standalone home screen
            context.go('/appmainscreen');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _shareDocument() async {
    if (_document == null) return;

    try {
      await ShareUtils.shareFiles(
        [XFile(_document!.filePath)],
        subject: _document!.title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  Future<void> _shareFile(String filePath) async {
    try {
      await ShareUtils.shareFiles([XFile(filePath)]);
    } catch (e) {
      debugPrint('Share failed: $e');
    }
  }

  Future<void> _deleteDocument() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${_document?.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DocumentService.instance.deleteDocument(widget.documentId);
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _showRenameDialog() async {
    if (_document == null) return;

    final controller = TextEditingController(text: _document!.title);
    final formKey = GlobalKey<FormState>();

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Document Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle != _document!.title && mounted) {
      try {
        await DocumentService.instance.renameDocument(widget.documentId, newTitle);
        setState(() {
          _document = _document!.copyWith(title: newTitle);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document renamed successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rename failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isModified,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (_isModified) {
          final shouldSave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unsaved Changes'),
              content: const Text('Do you want to save your changes?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Discard'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            ),
          );

          if (shouldSave == true) {
            await _saveDocument();
          }
          
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _document?.title ?? 'Text Document',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: _showRenameDialog,
                tooltip: 'Rename',
              ),
            ],
          ),
          actions: [
            if (_isModified)
              IconButton(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                onPressed: _isSaving ? null : _saveDocument,
                tooltip: 'Save',
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    _exportToWord();
                    break;
                  case 'share':
                    _shareDocument();
                    break;
                  case 'delete':
                    _deleteDocument();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download),
                      SizedBox(width: 12),
                      Text('Export to Word'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share),
                      SizedBox(width: 12),
                      Text('Share'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _document == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Document info bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _document!.format == 'txt'
                              ? Icons.text_snippet
                              : Icons.description,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _document!.format.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Text(
                                '${_textController.text.length} characters',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isModified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Modified',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Text editor
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Start typing or paste your text here...',
                          hintStyle: GoogleFonts.inter(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.dividerColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.dividerColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ),

                  // Bottom action bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _exportToWord,
                            icon: const Icon(Icons.file_download),
                            label: const Text('Export to Word'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _shareDocument,
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
