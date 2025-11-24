import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/core/services/docx_generator_service.dart';
import 'package:thyscan/features/scan/presentation/widgets/loading_overlay.dart';
import 'package:thyscan/features/scan/providers/translation_provider.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

class TranslationEditorScreen extends ConsumerStatefulWidget {
  final String? documentId;

  const TranslationEditorScreen({
    super.key,
    this.documentId,
  });

  @override
  ConsumerState<TranslationEditorScreen> createState() =>
      _TranslationEditorScreenState();
}

class _TranslationEditorScreenState
    extends ConsumerState<TranslationEditorScreen> {
  late final TextEditingController _controller;
  DocumentModel? _document;
  bool _isModified = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    
    if (widget.documentId != null) {
      _loadDocument();
    } else {
      // Initialize with current provider state if new translation
      final state = ref.read(translationProvider);
      _controller.text = state.translatedText;
    }

    _controller.addListener(() {
      if (!_isModified) {
        setState(() => _isModified = true);
      }
      // Update provider state
      ref.read(translationProvider.notifier).updateTranslatedText(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    try {
      final box = Hive.box<DocumentModel>(DocumentService.boxName);
      final doc = box.get(widget.documentId);

      if (doc != null && mounted) {
        setState(() {
          _document = doc;
          _controller.text = doc.textContent ?? '';
          // Update provider with loaded text
          ref.read(translationProvider.notifier).updateTranslatedText(doc.textContent ?? '');
        });
      }
    } catch (e) {
      debugPrint('Failed to load document: $e');
    }
  }

  Future<void> _saveDocument() async {
    setState(() => _isSaving = true);

    try {
      final text = _controller.text;
      DocumentModel? savedDoc;

      if (_document != null) {
        // Update existing document
        savedDoc = DocumentModel(
          id: _document!.id,
          title: _document!.title,
          filePath: _document!.filePath,
          format: _document!.format,
          createdAt: _document!.createdAt,
          pageCount: _document!.pageCount,
          thumbnailPath: _document!.thumbnailPath,
          scanMode: _document!.scanMode,
          textContent: text,
          pageImagePaths: _document!.pageImagePaths,
        );
        
        final box = Hive.box<DocumentModel>(DocumentService.boxName);
        await box.put(_document!.id, savedDoc);
        
        // Update text file
        final file = File(_document!.filePath);
        await file.writeAsString(text);
      } else {
        // Save new document
        savedDoc = await DocumentService.instance.saveTextDocument(
          text: text,
          title: 'Translation ${DateTime.now().toString()}',
          scanMode: 'translate',
        );
      }

      if (mounted) {
        setState(() {
          _document = savedDoc;
          _isModified = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
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

  Future<void> _onCopyPressed() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to copy')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _onExportDocxPressed() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      final docxPath = await DocxGeneratorService.instance.generateDocxFromText(
        text: text,
        title: _document?.title ?? 'Translation',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: ${docxPath.split('/').last}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () => Share.shareXFiles([XFile(docxPath)]),
            ),
          ),
        );
        
        // Navigate to home screen
        context.go('/appmainscreen');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _onSharePressed() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      await Share.share(text, subject: _document?.title ?? 'Translation');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  Future<void> _onChangeLanguagePressed() async {
    final state = ref.read(translationProvider);
    final current = state.targetLanguage;
    final languages = SupportedLanguage.values;

    final selected = await showModalBottomSheet<SupportedLanguage>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Translate to',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    return RadioListTile<SupportedLanguage>(
                      value: lang,
                      groupValue: current,
                      title: Text(lang.label),
                      onChanged: (value) {
                        Navigator.of(ctx).pop(value);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null || selected == current) return;

    final controller = ref.read(translationProvider.notifier);

    await LoadingOverlay.runWithDelay<void>(
      context: context,
      message: 'Translating…',
      action: () => controller.changeTargetLanguage(selected),
    );
    
    // Update controller with new translation
    if (mounted) {
      _controller.text = ref.read(translationProvider).translatedText;
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
        await DocumentService.instance.renameDocument(widget.documentId!, newTitle);
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
    final state = ref.watch(translationProvider);

    return WillPopScope(
      onWillPop: () async {
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
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _document?.title ?? 'Translation',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_document != null)
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: _showRenameDialog,
                  tooltip: 'Rename',
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Change language',
              icon: const Icon(Icons.translate_rounded),
              onPressed: _onChangeLanguagePressed,
            ),
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
          ],
        ),
        body: Column(
          children: [
            // Info bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
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
                    Icons.translate,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.targetLanguage.label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${_controller.text.length} characters',
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
                        color: Colors.orange.withOpacity(0.2),
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
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Translation will appear here...',
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
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _onExportDocxPressed,
                      icon: const Icon(Icons.file_download),
                      label: const Text('Word'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _onCopyPressed,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _onSharePressed,
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
