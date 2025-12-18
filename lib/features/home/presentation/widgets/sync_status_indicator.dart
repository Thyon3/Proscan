// features/home/presentation/widgets/sync_status_indicator.dart
import 'package:flutter/material.dart';
import 'package:thyscan/core/services/document_download_service.dart';
import 'package:thyscan/core/services/document_sync_service.dart';
import 'package:thyscan/core/services/document_sync_state_service.dart';
import 'package:thyscan/core/services/document_upload_service.dart';
import 'package:thyscan/core/services/offline_first_service.dart';
import 'package:thyscan/models/document_model.dart';
import 'package:thyscan/services/document_service.dart';

/// Widget that displays sync status for a document
class SyncStatusIndicator extends StatelessWidget {
  final String documentId;
  final double size;

  const SyncStatusIndicator({
    super.key,
    required this.documentId,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSyncStatusUpdate>(
      stream: DocumentSyncStateService.instance.statusStream
          .where((update) => update.documentId == documentId),
      initialData: null,
      builder: (context, snapshot) {
        final status = snapshot.hasData && snapshot.data != null
            ? snapshot.data!.status
            : DocumentSyncStateService.instance.getSyncStatus(documentId);

        IconData iconData;
        Color color;
        String? tooltip;

        switch (status) {
          case DocumentSyncStatus.synced:
            iconData = Icons.check_circle;
            color = Colors.green;
            tooltip = 'Synced';
            break;
          case DocumentSyncStatus.pendingUpload:
            iconData = Icons.cloud_upload;
            color = Colors.orange;
            tooltip = 'Pending upload';
            break;
          case DocumentSyncStatus.pendingDownload:
            iconData = Icons.cloud_download;
            color = Colors.blue;
            tooltip = 'Downloading...';
            break;
          case DocumentSyncStatus.syncing:
            iconData = Icons.sync;
            color = Colors.blue;
            tooltip = 'Syncing...';
            break;
          case DocumentSyncStatus.uploadingFile:
            iconData = Icons.cloud_upload;
            color = Colors.blue;
            tooltip = 'Uploading file...';
            break;
          case DocumentSyncStatus.uploadingThumbnail:
            iconData = Icons.image;
            color = Colors.blue;
            tooltip = 'Uploading thumbnail...';
            break;
          case DocumentSyncStatus.syncingMetadata:
            iconData = Icons.sync;
            color = Colors.blue;
            tooltip = 'Syncing metadata...';
            break;
          case DocumentSyncStatus.conflict:
            iconData = Icons.warning;
            color = Colors.red;
            tooltip = 'Conflict detected';
            break;
          case DocumentSyncStatus.pendingConflictResolution:
            iconData = Icons.warning;
            color = Colors.orange;
            tooltip = 'Conflict - resolution pending';
            break;
          case DocumentSyncStatus.error:
            iconData = Icons.error;
            color = Colors.red;
            tooltip = 'Sync error';
            break;
          case DocumentSyncStatus.failedRetry:
            iconData = Icons.refresh;
            color = Colors.orange;
            tooltip = 'Retrying...';
            break;
          case DocumentSyncStatus.failedSyncDelete:
            iconData = Icons.error;
            color = Colors.red;
            tooltip = 'Delete sync failed';
            break;
          case DocumentSyncStatus.failed:
            iconData = Icons.error_outline;
            color = Colors.red;
            tooltip = 'Sync failed after multiple attempts';
            break;
        }

        return Tooltip(
          message: tooltip,
          child: Icon(
            iconData,
            size: size,
            color: color,
          ),
        );
      },
    );
  }
}

/// Global sync status indicator for app bar
/// Shows overall sync progress and allows viewing pending operations
class GlobalSyncStatusIndicator extends StatelessWidget {
  const GlobalSyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSyncStatusUpdate>(
      stream: DocumentSyncStateService.instance.statusStream,
      builder: (context, snapshot) {
        final stats = DocumentSyncStateService.instance.getStatistics();

        if (stats.total == 0) {
          return const SizedBox.shrink();
        }

        // Show indicator if there are pending operations or issues
        if (!stats.hasPendingOperations && !stats.hasIssues) {
          return const SizedBox.shrink();
        }

        IconData iconData;
        Color color;
        String tooltip;

        if (stats.hasIssues) {
          iconData = Icons.warning;
          color = Colors.red;
          tooltip = '${stats.conflict + stats.error} sync issue(s) - Tap to view';
        } else if (stats.syncing > 0) {
          iconData = Icons.sync;
          color = Colors.blue;
          tooltip = 'Syncing ${stats.syncing} document(s)... - Tap to view';
        } else if (stats.pendingUpload > 0 || stats.pendingDownload > 0) {
          iconData = Icons.cloud_sync;
          color = Colors.orange;
          final pending = stats.pendingUpload + stats.pendingDownload;
          tooltip = '$pending document(s) pending sync - Tap to view';
        } else {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => _showSyncStatusDialog(context, stats),
          child: Tooltip(
            message: tooltip,
            child: Icon(
              iconData,
              size: 20,
              color: color,
            ),
          ),
        );
      },
    );
  }

  void _showSyncStatusDialog(BuildContext context, SyncStatistics stats) {
    showDialog(
      context: context,
      builder: (context) => _SyncStatusDialog(stats: stats),
    );
  }
}

/// Dialog showing detailed sync status with pending operations and retry options
class _SyncStatusDialog extends StatefulWidget {
  final SyncStatistics stats;

  const _SyncStatusDialog({required this.stats});

  @override
  State<_SyncStatusDialog> createState() => _SyncStatusDialogState();
}

class _SyncStatusDialogState extends State<_SyncStatusDialog> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stats = DocumentSyncStateService.instance.getStatistics();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_sync),
          SizedBox(width: 8),
          Text('Sync Status'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary
            _buildStatRow(
              context,
              'Total Documents',
              stats.total.toString(),
              colorScheme.primary,
            ),
            _buildStatRow(
              context,
              'Synced',
              stats.synced.toString(),
              Colors.green,
            ),
            if (stats.syncing > 0)
              _buildStatRow(
                context,
                'Syncing',
                stats.syncing.toString(),
                Colors.blue,
              ),
            if (stats.pendingUpload > 0)
              _buildStatRow(
                context,
                'Pending Upload',
                stats.pendingUpload.toString(),
                Colors.orange,
              ),
            if (stats.pendingDownload > 0)
              _buildStatRow(
                context,
                'Pending Download',
                stats.pendingDownload.toString(),
                Colors.blue,
              ),
            if (stats.conflict > 0)
              _buildStatRow(
                context,
                'Conflicts',
                stats.conflict.toString(),
                Colors.red,
              ),
            if (stats.error > 0)
              _buildStatRow(
                context,
                'Errors',
                stats.error.toString(),
                Colors.red,
              ),
            const Divider(height: 32),
            // Pending operations list
            if (stats.pendingUpload > 0 || stats.pendingDownload > 0)
              _buildPendingOperationsSection(context, colorScheme),
            // Failed operations with retry
            if (stats.error > 0) _buildFailedOperationsSection(context, colorScheme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (stats.hasPendingOperations || stats.hasIssues)
          FilledButton.icon(
            onPressed: _isRetrying
                ? null
                : () async {
                    setState(() => _isRetrying = true);
                    try {
                      // Retry failed uploads via syncNow
                      await DocumentUploadService.instance.syncNow();
                      // Retry sync
                      await DocumentSyncService.instance.syncDocuments(
                        forceFullSync: false,
                        replaceLocal: false,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sync retry initiated'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Retry failed: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isRetrying = false);
                      }
                    }
                  },
            icon: _isRetrying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(_isRetrying ? 'Retrying...' : 'Retry All'),
          ),
      ],
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingOperationsSection(BuildContext context, ColorScheme colorScheme) {
    final pendingUploads = DocumentUploadService.instance.pendingUploads;
    final pendingUploadCount = pendingUploads.length;
    final pendingDownloadCount = DocumentDownloadService.instance.queueLength;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Operations',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (pendingUploadCount == 0 && pendingDownloadCount == 0)
          const Text('No pending operations')
        else
          Column(
            children: [
              ...pendingUploads.take(5).map((upload) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.cloud_upload, size: 20),
                    title: Text(
                      upload.document.title,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )),
              if (pendingDownloadCount > 0)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.cloud_download, size: 20),
                  title: Text(
                    '$pendingDownloadCount document(s) pending download',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (pendingUploadCount + pendingDownloadCount > 10)
                Text(
                  '... and ${pendingUploadCount + pendingDownloadCount - 10} more',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFailedOperationsSection(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Failed Operations',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Some operations failed. Tap "Retry All" to attempt synchronization again.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

