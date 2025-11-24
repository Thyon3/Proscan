import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  List<DocumentModel> _searchResults = [];
  List<ToolItem> _toolResults = [];
  bool _isSearching = false;
  String _searchQuery = '';
  
  // Available tools
  final List<ToolItem> _allTools = [
    ToolItem(
      name: 'Scan Document',
      icon: Icons.document_scanner,
      description: 'Scan a new document',
      route: '/camerascreen',
    ),
    ToolItem(
      name: 'Extract Text',
      icon: Icons.text_fields,
      description: 'Extract text from image',
      route: '/camerascreen',
    ),
    ToolItem(
      name: 'Translate',
      icon: Icons.translate,
      description: 'Translate text',
      route: '/translationeditorscreen',
    ),
    ToolItem(
      name: 'ID Scanner',
      icon: Icons.badge,
      description: 'Scan ID cards',
      route: '/camerascreen',
    ),
    ToolItem(
      name: 'Receipt Scanner',
      icon: Icons.receipt,
      description: 'Scan receipts',
      route: '/camerascreen',
    ),
    ToolItem(
      name: 'Barcode Scanner',
      icon: Icons.qr_code_scanner,
      description: 'Scan barcodes and QR codes',
      route: '/camerascreen',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchFocus.requestFocus();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _performSearch();
    });
  }

  void _performSearch() {
    if (_searchQuery.isEmpty) {
      _searchResults = [];
      _toolResults = [];
      _isSearching = false;
      return;
    }

    _isSearching = true;
    final query = _searchQuery.toLowerCase();

    // Search documents
    final allDocs = DocumentService.instance.getAllDocuments();
    _searchResults = allDocs.where((doc) {
      return doc.title.toLowerCase().contains(query) ||
             doc.format.toLowerCase().contains(query);
    }).toList();

    // Search tools
    _toolResults = _allTools.where((tool) {
      return tool.name.toLowerCase().contains(query) ||
             tool.description.toLowerCase().contains(query);
    }).toList();
  }

  void _openDocument(DocumentModel doc) {
    if (doc.format == 'txt' || doc.format == 'docx') {
      context.push('/textdocumentscreen', extra: {'documentId': doc.id});
    } else {
      context.push('/savepdfscreen', extra: {
        'imagePaths': doc.pageImagePaths.isNotEmpty 
            ? doc.pageImagePaths 
            : [doc.thumbnailPath],
        'pdfFileName': doc.title,
        'documentId': doc.id,
        'scanMode': doc.scanMode,
      });
    }
  }

  void _openTool(ToolItem tool) {
    context.push(tool.route);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _toolResults = [];
      _isSearching = false;
    });
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasResults = _searchResults.isNotEmpty || _toolResults.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      style: GoogleFonts.inter(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search documents and tools...',
                        hintStyle: GoogleFonts.inter(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.search,
                          color: theme.colorScheme.primary,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.clear),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search results
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildEmptyState()
                  : hasResults
                      ? _buildSearchResults()
                      : _buildNoResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Searches',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.search,
                  size: 64,
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Search for documents or tools',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ..._allTools.take(4).map((tool) => _buildToolSuggestion(tool)),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tools section
        if (_toolResults.isNotEmpty) ...[
          _buildSectionHeader('Tools', _toolResults.length),
          const SizedBox(height: 12),
          ..._toolResults.map((tool) => _buildToolResult(tool)),
          const SizedBox(height: 24),
        ],

        // Documents section
        if (_searchResults.isNotEmpty) ...[
          _buildSectionHeader('Documents', _searchResults.length),
          const SizedBox(height: 12),
          ..._searchResults.map((doc) => _buildDocumentResult(doc)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolResult(ToolItem tool) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: () => _openTool(tool),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            tool.icon,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        title: Text(
          tool.name,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          tool.description,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
    );
  }

  Widget _buildToolSuggestion(ToolItem tool) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => _openTool(tool),
        leading: Icon(
          tool.icon,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        title: Text(
          tool.name,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
    );
  }

  Widget _buildDocumentResult(DocumentModel doc) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: () => _openDocument(doc),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 50,
            height: 50,
            color: theme.colorScheme.surfaceVariant,
            child: doc.thumbnailPath.isNotEmpty && File(doc.thumbnailPath).existsSync()
                ? Image.file(
                    File(doc.thumbnailPath),
                    fit: BoxFit.cover,
                  )
                : Icon(
                    doc.format == 'pdf'
                        ? Icons.picture_as_pdf
                        : Icons.description,
                    color: theme.colorScheme.primary,
                  ),
          ),
        ),
        title: Text(
          doc.title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    doc.format.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${doc.pageCount} page${doc.pageCount == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(doc.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}

class ToolItem {
  final String name;
  final IconData icon;
  final String description;
  final String route;

  ToolItem({
    required this.name,
    required this.icon,
    required this.description,
    required this.route,
  });
}
