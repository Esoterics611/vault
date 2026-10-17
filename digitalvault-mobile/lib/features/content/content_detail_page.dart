import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/content_provider.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/services/content_browse_service.dart';
import '../../core/contracts/content_registry_contract.dart';
import 'widgets/purchase_dialog.dart';

/// Content Detail Page
///
/// Displays detailed information about a specific content item.
class ContentDetailPage extends ConsumerWidget {
  final BigInt contentId;

  const ContentDetailPage({
    super.key,
    required this.contentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(contentItemProvider(contentId));

    return Scaffold(
      body: contentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading content',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
        data: (content) {
          if (content == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.not_interested, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Content not found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // App Bar with Hero Image
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _getCategoryGradient(content.category),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _getCategoryIcon(content.category),
                        size: 120,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ),
              ),

              // Content Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        content.title ?? 'Untitled',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Category and Price Row
                      Row(
                        children: [
                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(content.category),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              content.category.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Access Model Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 14,
                                  color: Colors.purple[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  content.accessModel.name.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.purple[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),

                          // Price
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: content.isFree ? Colors.green[50] : Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: content.isFree ? Colors.green : Colors.blue,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              content.formattedPrice,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: content.isFree ? Colors.green[700] : Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Description
                      if (content.description != null) ...[
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          content.description!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Details Card
                      Card(
                        elevation: 0,
                        color: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Content Details',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 16),

                              _DetailRow(
                                icon: Icons.fingerprint,
                                label: 'Content ID',
                                value: content.id.toString(),
                                copyable: true,
                              ),
                              const Divider(height: 24),

                              _DetailRow(
                                icon: Icons.storage,
                                label: 'File Size',
                                value: content.formattedFileSize,
                              ),
                              const Divider(height: 24),

                              _DetailRow(
                                icon: Icons.calendar_today,
                                label: 'Uploaded',
                                value: _formatDate(content.timestamp),
                              ),
                              const Divider(height: 24),

                              _DetailRow(
                                icon: Icons.person,
                                label: 'Owner',
                                value: _shortenAddress(content.owner),
                                copyable: true,
                                fullValue: content.owner,
                              ),

                              if (content.ipfsCid != null) ...[
                                const Divider(height: 24),
                                _DetailRow(
                                  icon: Icons.cloud,
                                  label: 'IPFS CID',
                                  value: _shortenHash(content.ipfsCid!),
                                  copyable: true,
                                  fullValue: content.ipfsCid!,
                                ),
                              ],

                              const Divider(height: 24),
                              _DetailRow(
                                icon: Icons.verified_user,
                                label: 'Status',
                                value: content.isActive ? 'Active' : 'Inactive',
                                valueColor: content.isActive ? Colors.green : Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      if (!content.isFree) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Check wallet connection
                              final walletState = ref.read(walletProvider);
                              if (!walletState.isConnected) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please connect your wallet first'),
                                  ),
                                );
                                return;
                              }

                              // Show purchase dialog
                              // Note: listingId should come from marketplace API
                              // For now, using contentId as placeholder
                              final result = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => PurchaseDialog(
                                  content: content,
                                  listingId: content.id, // TODO: Get actual listingId
                                ),
                              );

                              if (result == true && context.mounted) {
                                // Navigate to My Content page
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Purchase successful! Check "My Content"'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.shopping_cart),
                            label: Text('Purchase for ${content.formattedPrice}'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Implement view/download flow
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('View feature coming soon!'),
                              ),
                            );
                          },
                          icon: Icon(content.isFree ? Icons.download : Icons.visibility),
                          label: Text(content.isFree ? 'Download' : 'Preview'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _getCategoryIcon(ContentCategory category) {
    switch (category) {
      case ContentCategory.journal:
        return Icons.article;
      case ContentCategory.music:
        return Icons.music_note;
      case ContentCategory.art:
        return Icons.image;
      case ContentCategory.video:
        return Icons.videocam;
      case ContentCategory.document:
        return Icons.description;
    }
  }

  Color _getCategoryColor(ContentCategory category) {
    switch (category) {
      case ContentCategory.journal:
        return Colors.purple;
      case ContentCategory.music:
        return Colors.pink;
      case ContentCategory.art:
        return Colors.orange;
      case ContentCategory.video:
        return Colors.red;
      case ContentCategory.document:
        return Colors.blue;
    }
  }

  List<Color> _getCategoryGradient(ContentCategory category) {
    switch (category) {
      case ContentCategory.journal:
        return [Colors.purple[300]!, Colors.purple[600]!];
      case ContentCategory.music:
        return [Colors.pink[300]!, Colors.pink[600]!];
      case ContentCategory.art:
        return [Colors.orange[300]!, Colors.orange[600]!];
      case ContentCategory.video:
        return [Colors.red[300]!, Colors.red[600]!];
      case ContentCategory.document:
        return [Colors.blue[300]!, Colors.blue[600]!];
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${difference.inDays ~/ 365 > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${difference.inDays ~/ 30 > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  String _shortenAddress(String address) {
    if (address.length <= 13) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _shortenHash(String hash) {
    if (hash.length <= 20) return hash;
    return '${hash.substring(0, 10)}...${hash.substring(hash.length - 10)}';
  }
}

/// Detail Row Widget
///
/// Displays a labeled detail with an icon.
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool copyable;
  final String? fullValue;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.copyable = false,
    this.fullValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
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
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (copyable)
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: fullValue ?? value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied $label to clipboard'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Copy',
          ),
      ],
    );
  }
}
