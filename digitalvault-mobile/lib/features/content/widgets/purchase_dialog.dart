import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/purchase_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/services/content_purchase_service.dart';
import '../../../core/services/content_browse_service.dart';
import '../../../core/contracts/content_registry_contract.dart';

/// Purchase Dialog
///
/// Shows purchase confirmation and progress.
class PurchaseDialog extends ConsumerStatefulWidget {
  final ContentItem content;
  final BigInt listingId;

  const PurchaseDialog({
    super.key,
    required this.content,
    required this.listingId,
  });

  @override
  ConsumerState<PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends ConsumerState<PurchaseDialog> {
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    // Reset state when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(purchaseProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final purchaseState = ref.watch(purchaseProvider);
    final walletState = ref.watch(walletProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            if (!_hasStarted) ...[
              Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Purchase Content',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),

              // Content Info
              _ContentInfoCard(content: widget.content),
              const SizedBox(height: 24),

              // Price Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Price:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.content.formattedPrice,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Balance Info
              if (walletState.isConnected) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Balance:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      '${walletState.vltcBalance} VLTC',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmPurchase,
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ] else if (purchaseState.isPurchasing) ...[
              // Progress Indicator
              const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                ),
              ),
              const SizedBox(height: 24),

              // Progress Text
              Text(
                purchaseState.stepMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // Progress Bar
              LinearProgressIndicator(
                value: purchaseState.progress,
                backgroundColor: Colors.grey[200],
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                '${(purchaseState.progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ] else if (purchaseState.result != null) ...[
              // Success
              const Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                'Purchase Successful!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'You now have access to this content',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 24),

              // Transaction Details (collapsed)
              _TransactionDetails(result: purchaseState.result!),
              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('View My Content'),
                ),
              ),
            ] else if (purchaseState.error != null) ...[
              // Error
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              Text(
                'Purchase Failed',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  purchaseState.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red[900],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _hasStarted = false);
                        ref.read(purchaseProvider.notifier).reset();
                      },
                      child: const Text('Try Again'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmPurchase() async {
    final walletState = ref.read(walletProvider);

    if (!walletState.isConnected || walletState.address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect your wallet first')),
      );
      return;
    }

    setState(() => _hasStarted = true);

    // Execute purchase
    final success = await ref.read(purchaseProvider.notifier).purchaseContent(
          listingId: widget.listingId,
          contentId: widget.content.id,
          buyerAddress: walletState.address!,
          title: widget.content.title ?? 'Untitled',
          ipfsCid: widget.content.ipfsCid ?? '',
          category: widget.content.category.name,
          fileSize: widget.content.fileSize,
          description: widget.content.description,
        );

    if (!success) {
      // Error state will be shown automatically
    }
  }
}

/// Content Info Card Widget
class _ContentInfoCard extends StatelessWidget {
  final ContentItem content;

  const _ContentInfoCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
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
            child: Icon(
              _getCategoryIcon(content.category),
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.title ?? 'Untitled',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  content.category.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content.formattedFileSize,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
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
}

/// Transaction Details Widget
class _TransactionDetails extends StatefulWidget {
  final PurchaseResult result;

  const _TransactionDetails({required this.result});

  @override
  State<_TransactionDetails> createState() => _TransactionDetailsState();
}

class _TransactionDetailsState extends State<_TransactionDetails> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaction Details',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailText('Content ID', widget.result.contentId.toString()),
                const Divider(height: 16),
                _DetailText('Listing ID', widget.result.listingId.toString()),
                const Divider(height: 16),
                _DetailText('Transaction Hash',
                    _shortenHash(widget.result.transactionHash)),
                const Divider(height: 16),
                _DetailText('Purchase Time', _formatTime(widget.result.purchaseTime)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _shortenHash(String hash) {
    if (hash.length <= 20) return hash;
    return '${hash.substring(0, 10)}...${hash.substring(hash.length - 10)}';
  }

  String _formatTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Detail Text Widget
class _DetailText extends StatelessWidget {
  final String label;
  final String value;

  const _DetailText(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
