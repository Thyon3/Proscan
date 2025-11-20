import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thyscan/features/scan/presentation/widgets/loading_overlay.dart';
import 'package:thyscan/features/scan/providers/translation_provider.dart';

/// Screen that displays the translated text in an editable text field with a
/// toolbar for actions: Change Language, Copy, Save as PDF, Save as Word.
class TranslationEditorScreen extends ConsumerStatefulWidget {
  const TranslationEditorScreen({super.key});

  @override
  ConsumerState<TranslationEditorScreen> createState() =>
      _TranslationEditorScreenState();
}

class _TranslationEditorScreenState
    extends ConsumerState<TranslationEditorScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onCopyPressed(TranslationState state) async {
    final text = state.translatedText.trim();
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
      const SnackBar(content: Text('Translated text copied to clipboard')),
    );
  }

  Future<void> _onExportPdfPressed() async {
    final controller = ref.read(translationProvider.notifier);
    final state = ref.read(translationProvider);

    if (state.translatedText.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export')),
      );
      return;
    }

    final file = await LoadingOverlay.runWithDelay<File?>(
      context: context,
      message: 'Generating PDF…',
      action: () => controller.exportAsPdf(),
    );

    if (!mounted) return;

    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create PDF')),
      );
      return;
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Translated text (PDF)',
    );
  }

  Future<void> _onExportDocxPressed() async {
    final controller = ref.read(translationProvider.notifier);
    final state = ref.read(translationProvider);

    if (state.translatedText.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export')),
      );
      return;
    }

    final file = await LoadingOverlay.runWithDelay<File?>(
      context: context,
      message: 'Generating Word document…',
      action: () => controller.exportAsDocx(),
    );

    if (!mounted) return;

    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create Word document')),
      );
      return;
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Translated text (DOCX)',
    );
  }

  Future<void> _onChangeLanguagePressed(TranslationState state) async {
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
                  color: Theme.of(ctx)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              for (final lang in languages)
                RadioListTile<SupportedLanguage>(
                  value: lang,
                  groupValue: current,
                  title: Text(lang.label),
                  onChanged: (value) {
                    Navigator.of(ctx).pop(value);
                  },
                ),
              const SizedBox(height: 8),
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
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(translationProvider);

    // Keep controller synchronized with provider state in a safe way.
    if (_controller.text != state.translatedText) {
      _controller.text = state.translatedText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Translate',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Change language',
            icon: const Icon(Icons.translate_rounded),
            onPressed: () => _onChangeLanguagePressed(state),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => _onCopyPressed(state),
          ),
          IconButton(
            tooltip: 'Save as PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _onExportPdfPressed,
          ),
          IconButton(
            tooltip: 'Save as Word',
            icon: const Icon(Icons.description_rounded),
            onPressed: _onExportDocxPressed,
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.errorMessage != null)
            MaterialBanner(
              content: Text(state.errorMessage!),
              backgroundColor: cs.errorContainer,
              contentTextStyle: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onErrorContainer,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    ref
                        .read(translationProvider.notifier)
                        .updateTranslatedText(state.translatedText);
                    ref
                        .read(translationProvider.notifier)
                        .updateSourceText(state.sourceText);
                  },
                  child: Text(
                    'DISMISS',
                    style: TextStyle(color: cs.onErrorContainer),
                  ),
                ),
              ],
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: theme.textTheme.bodyMedium,
                  decoration: const InputDecoration(
                    hintText: 'Translated text will appear here',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  onChanged: (value) => ref
                      .read(translationProvider.notifier)
                      .updateTranslatedText(value),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
