import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers/purchase_provider.dart';
import '../../core/services/content_access_service.dart';

/// Content Viewer Page
///
/// Displays and allows interaction with owned content.
class ContentViewerPage extends ConsumerStatefulWidget {
  final OwnedContent content;

  const ContentViewerPage({
    super.key,
    required this.content,
  });

  @override
  ConsumerState<ContentViewerPage> createState() => _ContentViewerPageState();
}

class _ContentViewerPageState extends ConsumerState<ContentViewerPage> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.content.title),
        actions: [
          if (widget.content.isDownloaded)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _showDeleteDialog,
              tooltip: 'Delete local file',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Content info',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Content Icon
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _getCategoryGradient(widget.content.category),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _getCategoryIcon(widget.content.category),
                  size: 80,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                widget.content.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              if (widget.content.description != null) ...[
                Text(
                  widget.content.description!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // File Size
              Text(
                widget.content.formattedFileSize,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // Download/View Button
              if (!widget.content.isDownloaded) ...[
                if (_isDownloading) ...[
                  // Download Progress
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      children: [
                        Center(
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              value: _downloadProgress,
                              strokeWidth: 6,
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '${(_downloadProgress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Downloading and decrypting...'),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _downloadAndDecrypt,
                      icon: const Icon(Icons.download),
                      label: const Text('Download & Decrypt'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Content will be decrypted and saved locally',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ] else ...[
                // View Downloaded Content
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      const Text(
                        'Downloaded',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _viewContent,
                    icon: Icon(_getViewIcon(widget.content.category)),
                    label: Text(_getViewLabel(widget.content.category)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openInExternalApp,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in External App'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadAndDecrypt() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final accessService = ref.read(contentAccessServiceProvider);

      await accessService.downloadAndDecrypt(
        contentId: widget.content.contentId,
        onProgress: (downloaded, total) {
          if (total > 0) {
            setState(() {
              _downloadProgress = downloaded / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        // Refresh content to get updated local path
        ref.invalidate(ownedContentProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content downloaded and decrypted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewContent() async {
    if (widget.content.localFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please download the content first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final file = File(widget.content.localFilePath!);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found. Please re-download.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // For MVP, use external app to view content
    // This provides the best UX as system apps handle file types natively
    _openInExternalApp();
  }

  Future<void> _openInExternalApp() async {
    if (widget.content.localFilePath == null) return;

    final file = File(widget.content.localFilePath!);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final result = await OpenFilex.open(widget.content.localFilePath!);

      if (result.type != ResultType.done) {
        // Show file path with option to copy
        if (mounted) {
          _showFileLocationDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Copy Path',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: widget.content.localFilePath!),
                );
              },
            ),
          ),
        );
      }
    }
  }

  void _showFileLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No app found to open this file. The file is saved at:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                widget.content.localFilePath!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: widget.content.localFilePath!),
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Path copied to clipboard')),
              );
            },
            child: const Text('Copy Path'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Share.shareXFiles(
                [XFile(widget.content.localFilePath!)],
                text: widget.content.title,
              );
            },
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Local File'),
        content: const Text(
          'Are you sure you want to delete the local copy? '
          'You can re-download it anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final accessService = ref.read(contentAccessServiceProvider);
                await accessService.deleteLocalFile(widget.content.contentId);

                ref.invalidate(ownedContentProvider);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Local file deleted'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Content Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoRow('Content ID', widget.content.contentId),
              _InfoRow('Title', widget.content.title),
              _InfoRow('Category', widget.content.category.toUpperCase()),
              _InfoRow('File Size', widget.content.formattedFileSize),
              _InfoRow('IPFS CID', widget.content.ipfsCid),
              _InfoRow(
                'Ownership',
                widget.content.isOriginalOwner ? 'Created' : 'Purchased',
              ),
              _InfoRow(
                'Acquired',
                _formatDateTime(widget.content.acquiredDate),
              ),
              _InfoRow(
                'Downloaded',
                widget.content.isDownloaded ? 'Yes' : 'No',
              ),
              if (widget.content.localFilePath != null)
                _InfoRow('Local Path', widget.content.localFilePath!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'journal':
        return Icons.article;
      case 'music':
        return Icons.music_note;
      case 'art':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'document':
        return Icons.description;
      default:
        return Icons.file_present;
    }
  }

  List<Color> _getCategoryGradient(String category) {
    switch (category.toLowerCase()) {
      case 'journal':
        return [Colors.purple[300]!, Colors.purple[600]!];
      case 'music':
        return [Colors.pink[300]!, Colors.pink[600]!];
      case 'art':
        return [Colors.orange[300]!, Colors.orange[600]!];
      case 'video':
        return [Colors.red[300]!, Colors.red[600]!];
      case 'document':
        return [Colors.blue[300]!, Colors.blue[600]!];
      default:
        return [Colors.grey[300]!, Colors.grey[600]!];
    }
  }

  IconData _getViewIcon(String category) {
    switch (category.toLowerCase()) {
      case 'art':
        return Icons.image;
      case 'video':
        return Icons.play_circle;
      case 'music':
        return Icons.play_arrow;
      default:
        return Icons.visibility;
    }
  }

  String _getViewLabel(String category) {
    switch (category.toLowerCase()) {
      case 'art':
        return 'View Image';
      case 'video':
        return 'Play Video';
      case 'music':
        return 'Play Audio';
      default:
        return 'View Content';
    }
  }
}

/// Info Row Widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
