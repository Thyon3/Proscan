# Backend Document Upload Fixes - Summary

## Issues Identified and Fixed

### 1. **Missing JSON Serialization Methods in DocumentModel**
**Problem:** The `DocumentModel` class had no `toJson()` and `fromJson()` methods for REST API communication with the backend, only Hive serialization.

**Fix:** Added proper JSON serialization methods to `lib/models/document_model.dart`:
- `toJson()` - Converts DocumentModel to JSON for sending to backend
- `fromJson()` - Creates DocumentModel from backend JSON response
- Handles field name mapping (e.g., `filePath` ↔ `fileUrl`, `thumbnailPath` ↔ `thumbnailUrl`)
- Proper null safety and default values

### 2. **Inconsistent Field Naming Between Frontend and Backend**
**Problem:** Frontend uses `filePath`/`thumbnailPath`, backend uses `fileUrl`/`thumbnailUrl`.

**Fix:** 
- JSON serialization methods now properly map field names
- `fromJson()` accepts both naming conventions for backward compatibility
- Backend sync service uses correct field names in API requests

### 3. **Null Value Handling in Metadata**
**Problem:** Sending `null` values in JSON was causing backend validation errors.

**Fix:** Modified `syncDocumentMetadata()` and `updateDocumentMetadata()` in `document_backend_sync_service.dart`:
```dart
final requestData = { /* ... fields ... */ };
requestData.removeWhere((key, value) => value == null);
final body = jsonEncode(requestData);
```

### 4. **Missing Timestamp Fields**
**Problem:** `createdAt` and `updatedAt` timestamps weren't being sent to backend.

**Fix:** Added timestamp fields to all API requests:
```dart
'createdAt': document.createdAt.toIso8601String(),
'updatedAt': document.updatedAt.toIso8601String(),
```

### 5. **Duplicate JSON Parsing in Signature Generation**
**Problem:** Code was doing `jsonDecode(body)` unnecessarily after already having the data structure.

**Fix:** Use `requestData` directly instead of decoding the JSON string:
```dart
// Before:
final requestBody = jsonDecode(body) as Map<String, dynamic>;
final signature = RequestSignatureService.instance.generateSignature(..., body: requestBody);

// After:
final signature = RequestSignatureService.instance.generateSignature(..., body: requestData);
```

### 6. **Inconsistent Error Handling in `_documentFromJson()`**
**Problem:** Custom `_documentFromJson()` method had duplicate logic and no error handling.

**Fix:** Simplified to use the new `DocumentModel.fromJson()` factory with proper error handling:
```dart
DocumentModel _documentFromJson(Map<String, dynamic> json) {
  try {
    return DocumentModel.fromJson(json);
  } catch (e, stack) {
    AppLogger.error('Failed to parse document from JSON', ...);
    rethrow;
  }
}
```

### 7. **Tags and Metadata Type Conversion**
**Problem:** Backend might send tags/metadata with different types than expected.

**Fix:** Added robust type conversion in `fromJson()`:
```dart
tags: json['tags'] != null
    ? (json['tags'] as List<dynamic>).map((e) => e.toString()).toList()
    : null,
metadata: json['metadata'] != null
    ? (json['metadata'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value.toString()),
      )
    : null,
```

## Files Modified

1. **lib/models/document_model.dart**
   - Added `toJson()` method
   - Added `fromJson()` factory constructor
   - Proper field name mapping and null safety

2. **lib/core/services/document_backend_sync_service.dart**
   - Fixed `syncDocumentMetadata()` - proper null handling and timestamps
   - Fixed `updateDocumentMetadata()` - proper null handling and timestamps
   - Simplified `_documentFromJson()` - uses DocumentModel.fromJson()
   - Removed duplicate JSON parsing in signature generation

## Testing Recommendations

1. **Test Document Upload Flow:**
   ```bash
   flutter test test/core/services/document_service_test.dart
   ```

2. **Test Backend Sync:**
   ```bash
   flutter test test/core/services/document_sync_service_test.dart
   ```

3. **Integration Tests:**
   ```bash
   flutter test integration_test/document_creation_flow_test.dart
   flutter test integration_test/sync_flow_test.dart
   ```

4. **Manual Testing:**
   - Create a new document with all fields populated
   - Upload document with empty optional fields (textContent, tags, metadata)
   - Update existing document metadata
   - Verify backend receives correct field names and values
   - Check logs for any remaining errors

## Expected Improvements

✅ **No more backend validation errors** - All fields properly formatted
✅ **Consistent field naming** - Proper mapping between frontend and backend
✅ **Better error messages** - Clear logging when JSON parsing fails
✅ **Industry-standard code** - Professional error handling and validation
✅ **Null safety** - No crashes from null values
✅ **Performance** - No unnecessary JSON parsing operations

## Backend API Expected Format

The backend should now receive requests in this format:

```json
{
  "id": "uuid-here",
  "title": "Document Title",
  "fileUrl": "https://storage.url/path/to/file.pdf",
  "thumbnailUrl": "https://storage.url/path/to/thumb.jpg",
  "format": "pdf",
  "pageCount": 5,
  "scanMode": "document",
  "colorProfile": "color",
  "textContent": "Optional text content",
  "tags": ["tag1", "tag2"],
  "metadata": {"key": "value"},
  "createdAt": "2025-01-18T10:00:00.000Z",
  "updatedAt": "2025-01-18T10:00:00.000Z"
}
```

Note: Null values are automatically removed from the request.
