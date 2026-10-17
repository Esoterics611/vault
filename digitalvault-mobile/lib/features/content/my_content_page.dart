import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../core/providers/purchase_provider.dart';
import '../../core/providers/content_provider.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/services/content_access_service.dart';
import '../../core/services/content_browse_service.dart';
import '../../core/services/transaction_history_service.dart';
import '../../core/contracts/content_registry_contract.dart'; // For ContentCategory
import '../marketplace/create_listing_dialog.dart';
import 'content_viewer_page.dart';

/// My Content Page
///
/// Displays the user's owned and purchased content library.
class MyContentPage extends ConsumerStatefulWidget {
  const MyContentPage({super.key});

  @override
  ConsumerState<MyContentPage> createState() => _MyContentPageState();
}

class _MyContentPageState extends ConsumerState<MyContentPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Content'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(ownedContentProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Created'),
            Tab(text: 'Purchased'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AllContentTab(),
          _CreatedContentTab(),
          _PurchasedContentTab(),
          _TransactionHistoryTab(),
        ],
      ),
    );
  }
}

/// All Content Tab
class _AllContentTab extends ConsumerWidget {
  const _AllContentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(ownedContentProvider);

    return contentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(ownedContentProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (content) {
        if (content.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 100, color: Colors.grey[300]),
                const SizedBox(height: 24),
                Text(
                  'No content yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload or purchase content to get started',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ownedContentProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: content.length,
            itemBuilder: (context, index) {
              return OwnedContentCard(content: content[index]);
            },
          ),
        );
      },
    );
  }
}

/// Created Content Tab
class _CreatedContentTab extends ConsumerWidget {
  const _CreatedContentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);

    // Need wallet connected to show created content
    if (!walletState.isConnected || walletState.address == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet, size: 100, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Wallet not connected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your wallet to view your created content',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final contentAsync = ref.watch(userCreatedContentProvider(walletState.address!));

    return contentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(userCreatedContentProvider(walletState.address!)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (contentItems) {
        if (contentItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file, size: 100, color: Colors.grey[300]),
                const SizedBox(height: 24),
                Text(
                  'No uploaded content',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload your first content to see it here',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userCreatedContentProvider(walletState.address!));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contentItems.length,
            itemBuilder: (context, index) {
              return CreatedContentCard(content: contentItems[index]);
            },
          ),
        );
      },
    );
  }
}

/// Purchased Content Tab
class _PurchasedContentTab extends ConsumerWidget {
  const _PurchasedContentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(contentByOwnershipProvider);

    return contentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (contentMap) {
        final purchased = contentMap['purchased'] ?? [];

        if (purchased.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag, size: 100, color: Colors.grey[300]),
                const SizedBox(height: 24),
                Text(
                  'No purchased content',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Browse the marketplace to purchase content',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: purchased.length,
          itemBuilder: (context, index) {
            return OwnedContentCard(content: purchased[index]);
          },
        );
      },
    );
  }
}

/// Owned Content Card Widget
class OwnedContentCard extends ConsumerWidget {
  final OwnedContent content;

  const OwnedContentCard({super.key, required this.content});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContentViewerPage(content: content),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _getCategoryGradient(content.category),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _getCategoryIcon(content.category),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    if (content.isDownloaded)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Content Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Category Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(content.category),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            content.category.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Ownership Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: content.isOriginalOwner
                                ? Colors.purple[100]
                                : Colors.blue[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            content.isOriginalOwner ? 'CREATED' : 'PURCHASED',
                            style: TextStyle(
                              color: content.isOriginalOwner
                                  ? Colors.purple[700]
                                  : Colors.blue[700],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          content.formattedFileSize,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Text(' • '),
                        Text(
                          _formatDate(content.acquiredDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow Icon
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
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

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'journal':
        return Colors.purple;
      case 'music':
        return Colors.pink;
      case 'art':
        return Colors.orange;
      case 'video':
        return Colors.red;
      case 'document':
        return Colors.blue;
      default:
        return Colors.grey;
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
}

/// Created Content Card Widget (for blockchain ContentItem)
class CreatedContentCard extends ConsumerWidget {
  final ContentItem content;

  const CreatedContentCard({super.key, required this.content});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getCategoryGradient(content.category),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      _getCategoryIcon(content.category),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Content Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.title ?? 'Untitled Content',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (content.description != null)
                        Text(
                          content.description!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(content.category),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              content.category.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Created Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'CREATED',
                              style: TextStyle(
                                color: Colors.purple[700],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // File Info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      content.formattedFileSize,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(content.timestamp),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // List for Sale Button
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showCreateListingDialog(context, content);
                },
                icon: const Icon(Icons.sell, size: 18),
                label: const Text('List for Sale'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateListingDialog(BuildContext context, ContentItem content) {
    showDialog(
      context: context,
      builder: (context) => CreateListingDialog(content: content),
    ).then((success) {
      if (success == true) {
        // Refresh the content list
        // The SnackBar is shown from the dialog
      }
    });
  }

  List<Color> _getCategoryGradient(ContentCategory category) {
    switch (category) {
      case ContentCategory.journal:
        return [Colors.green[400]!, Colors.green[600]!];
      case ContentCategory.music:
        return [Colors.purple[400]!, Colors.purple[600]!];
      case ContentCategory.art:
        return [Colors.blue[400]!, Colors.blue[600]!];
      case ContentCategory.video:
        return [Colors.red[400]!, Colors.red[600]!];
      case ContentCategory.document:
        return [Colors.orange[400]!, Colors.orange[600]!];
    }
  }

  IconData _getCategoryIcon(ContentCategory category) {
    switch (category) {
      case ContentCategory.journal:
        return Icons.article;
      case ContentCategory.music:
        return Icons.audio_file;
      case ContentCategory.art:
        return Icons.image;
      case ContentCategory.video:
        return Icons.video_library;
      case ContentCategory.document:
        return Icons.description;
    }
  }

  Color _getCategoryColor(ContentCategory category) {
    switch (category) {
      case ContentCategory.journal:
        return Colors.green;
      case ContentCategory.music:
        return Colors.purple;
      case ContentCategory.art:
        return Colors.blue;
      case ContentCategory.video:
        return Colors.red;
      case ContentCategory.document:
        return Colors.orange;
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
}

/// Transaction History Tab Widget
class _TransactionHistoryTab extends ConsumerWidget {
  const _TransactionHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);

    if (!walletState.isConnected || walletState.address == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wallet, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Connect your wallet to view transactions',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final web3Service = ref.watch(web3ServiceProvider);
    final contractService = ref.watch(contractServiceProvider);
    final transactionService = TransactionHistoryService(web3Service, contractService);

    return FutureBuilder<List<TransactionHistoryItem>>(
      future: transactionService.getTransactionHistory(walletState.address!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading transactions',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Trigger rebuild
                    (context as Element).markNeedsBuild();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final transactions = snapshot.data ?? [];

        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No Transactions Yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your transaction history will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            return _TransactionCard(transaction: transactions[index]);
          },
        );
      },
    );
  }
}

/// Transaction Card Widget
class _TransactionCard extends StatelessWidget {
  final TransactionHistoryItem transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTransactionDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getTypeColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTypeIcon(),
                  color: _getTypeColor(),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          transaction.typeString,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (transaction.isSuccess)
                          Icon(Icons.check_circle,
                            color: Colors.green[600], size: 16)
                        else
                          Icon(Icons.error,
                            color: Colors.red[600], size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(transaction.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (transaction.contentId != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Content ID: ${transaction.contentId.toString().substring(0, 8)}...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Transaction Hash (Copy button)
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: transaction.txHash));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction hash copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: 'Copy transaction hash',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (transaction.type) {
      case TransactionType.contentRegistered:
        return Colors.blue;
      case TransactionType.contentPurchased:
        return Colors.green;
      case TransactionType.listingCreated:
        return Colors.orange;
      case TransactionType.ownershipTransferred:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon() {
    switch (transaction.type) {
      case TransactionType.contentRegistered:
        return Icons.cloud_upload;
      case TransactionType.contentPurchased:
        return Icons.shopping_cart;
      case TransactionType.listingCreated:
        return Icons.sell;
      case TransactionType.ownershipTransferred:
        return Icons.send;
      default:
        return Icons.swap_horiz;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showTransactionDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getTypeColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getTypeIcon(),
                    color: _getTypeColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Transaction Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _DetailRow(label: 'Type', value: transaction.typeString),
            _DetailRow(label: 'Status', value: transaction.isSuccess ? 'Success' : 'Failed'),
            _DetailRow(
              label: 'Time',
              value: _formatTimestamp(transaction.timestamp),
            ),
            if (transaction.contentId != null)
              _DetailRow(label: 'Content ID', value: transaction.contentId.toString()),
            if (transaction.formattedAmount != null)
              _DetailRow(
                label: 'Amount',
                value: transaction.formattedAmount!,
              ),
            _DetailRow(
              label: 'Transaction Hash',
              value: transaction.shortTxHash,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Open in Basescan
                  final url =
                      'https://sepolia.basescan.org/tx/${transaction.txHash}';
                  // In a real app, you'd use url_launcher package
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('View on Basescan: $url')),
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('View on Basescan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail Row Widget
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
