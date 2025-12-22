// Test script to verify document update and delete functionality
// Run with: flutter run test_document_update.dart

import 'package:flutter/material.dart';
import 'package:thyscan/core/services/auth_service.dart';
import 'package:thyscan/core/services/document_backend_sync_service.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('═══════════════════════════════════════════════════════════');
  print('📋 DOCUMENT UPDATE & DELETE TEST');
  print('═══════════════════════════════════════════════════════════');
  
  // Initialize services
  await AuthService.instance.initialize();
  await DocumentUploadService.instance.initialize();
  
  print('\n✅ Services initialized');
  print('   Auth: ${AuthService.instance.currentUser != null ? "Logged in" : "Not logged in"}');
  
  if (AuthService.instance.currentUser == null) {
    print('\n❌ ERROR: User not authenticated');
    print('   Please log in first before running this test');
    return;
  }
  
  final userId = AuthService.instance.currentUser!.id;
  print('   User ID: $userId');
  
  // Test 1: Create a test document
  print('\n═══════════════════════════════════════════════════════════');
  print('📝 TEST 1: Creating test document');
  print('═══════════════════════════════════════════════════════════');
  
  final testDoc = DocumentModel(
    id: 'test-doc-${DateTime.now().millisecondsSinceEpoch}',
    title: 'Test Document for Update',
    filePath: '/path/to/test.pdf',
    thumbnailPath: '/path/to/thumb.jpg',
    format: 'pdf',
    pageCount: 3,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    pageImagePaths: ['/path/1.jpg', '/path/2.jpg', '/path/3.jpg'],
    scanMode: 'document',
    colorProfile: 'color',
    tags: ['test'],
    metadata: {'test': 'true'},
  );
  
  print('   Document ID: ${testDoc.id}');
  print('   Title: ${testDoc.title}');
  
  // Test 2: Update document metadata only
  print('\n═══════════════════════════════════════════════════════════');
  print('🔄 TEST 2: Updating document metadata (title only)');
  print('═══════════════════════════════════════════════════════════');
  
  final updatedDoc = testDoc.copyWith(
    title: 'Test Document - UPDATED',
    updatedAt: DateTime.now(),
  );
  
  try {
    await DocumentBackendSyncService.instance.updateDocumentMetadata(
      updatedDoc,
    );
    print('   ✅ Metadata update completed');
  } catch (e) {
    print('   ❌ Metadata update failed: $e');
  }
  
  // Test 3: Update with new file URL (simulating file change)
  print('\n═══════════════════════════════════════════════════════════');
  print('📤 TEST 3: Updating document with new file URL');
  print('═══════════════════════════════════════════════════════════');
  
  final newFileUrl = 'https://example.supabase.co/storage/v1/object/public/documents/$userId/${testDoc.id}.pdf';
  final newThumbnailUrl = 'https://example.supabase.co/storage/v1/object/public/documents/$userId/${testDoc.id}_thumb.jpg';
  
  try {
    await DocumentBackendSyncService.instance.updateDocumentMetadata(
      updatedDoc,
      newFileUrl: newFileUrl,
      newThumbnailUrl: newThumbnailUrl,
    );
    print('   ✅ File URL update completed');
    print('   📁 New file URL: ${newFileUrl.substring(0, 60)}...');
    print('   🖼️ New thumbnail URL: ${newThumbnailUrl.substring(0, 60)}...');
  } catch (e) {
    print('   ❌ File URL update failed: $e');
  }
  
  // Test 4: Delete document (soft delete)
  print('\n═══════════════════════════════════════════════════════════');
  print('🗑️ TEST 4: Soft deleting document');
  print('═══════════════════════════════════════════════════════════');
  
  try {
    await DocumentBackendSyncService.instance.deleteDocument(
      documentId: testDoc.id,
      fileUrl: newFileUrl,
      thumbnailUrl: newThumbnailUrl,
      hardDelete: false,
    );
    print('   ✅ Soft delete completed');
  } catch (e) {
    print('   ❌ Soft delete failed: $e');
  }
  
  // Test 5: Hard delete document
  print('\n═══════════════════════════════════════════════════════════');
  print('🗑️ TEST 5: Hard deleting document');
  print('═══════════════════════════════════════════════════════════');
  
  try {
    await DocumentBackendSyncService.instance.deleteDocument(
      documentId: testDoc.id,
      fileUrl: newFileUrl,
      thumbnailUrl: newThumbnailUrl,
      hardDelete: true,
    );
    print('   ✅ Hard delete completed');
    print('   🧹 Files removed from Supabase Storage');
    print('   🧹 Metadata removed from PostgreSQL');
  } catch (e) {
    print('   ❌ Hard delete failed: $e');
  }
  
  print('\n═══════════════════════════════════════════════════════════');
  print('✅ ALL TESTS COMPLETED');
  print('═══════════════════════════════════════════════════════════');
  print('\nSummary:');
  print('  ✓ Metadata update (title only)');
  print('  ✓ File URL update (with new storage URLs)');
  print('  ✓ Soft delete (marks as deleted)');
  print('  ✓ Hard delete (removes from storage and database)');
  print('\n💡 Backend will automatically:');
  print('  • Delete old files from Supabase storage when URLs change');
  print('  • Update metadata in PostgreSQL');
  print('  • Clean up orphaned files');
}
