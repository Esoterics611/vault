import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction_model.dart';

/// Transaction Status Widget
///
/// Inline widget that displays recent transactions with real-time status updates.
/// Can be embedded in any page (home, content, etc.).
class TransactionStatusWidget extends ConsumerWidget {
  final int maxTransactions;
  final bool showViewAll;

  const TransactionStatusWidget({
    super.key,
    this.maxTransactions = 3,
    this.showViewAll = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionState = ref.watch(transactionHistoryProvider);
    final transactions = transactionState.transactions;

    if (transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get recent transactions (reversed for newest first)
    final recentTransactions = transactions.reversed.take(maxTransactions).toList();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (showViewAll && transactions.length > maxTransactions)
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/transactions'),
                    child: const Text('View All'),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Transaction list
          ...recentTransactions.map((tx) => _TransactionItem(transaction: tx)),
        ],
      ),
    );
  }
}

/// Transaction Item
///
/// Compact transaction display for inline use.
class _TransactionItem extends StatelessWidget {
  final TransactionModel transaction;

  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildStatusIcon(),
      title: Text(
        transaction.operation,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _formatHash(transaction.hash),
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
      trailing: _buildStatusChip(context),
      onTap: () => _showTransactionDialog(context),
    );
  }

  Widget _buildStatusIcon() {
    Color color;
    IconData icon;

    switch (transaction.status) {
      case TransactionStatus.pending:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case TransactionStatus.confirmed:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case TransactionStatus.failed:
        color = Colors.red;
        icon = Icons.error;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    Color color;
    String label;

    switch (transaction.status) {
      case TransactionStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case TransactionStatus.confirmed:
        color = Colors.green;
        label = 'Done';
        break;
      case TransactionStatus.failed:
        color = Colors.red;
        label = 'Failed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatHash(String hash) {
    if (hash.length <= 20) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 6)}';
  }

  void _showTransactionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(transaction.operation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(context, 'Status', transaction.statusText),
            _buildDetailRow(context, 'Hash', transaction.hash),
            if (transaction.error != null)
              _buildDetailRow(context, 'Error', transaction.error!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: transaction.hash));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hash copied')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
          TextButton.icon(
            onPressed: () => _openBasescan(context),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Basescan'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  void _openBasescan(BuildContext context) async {
    final url = Uri.parse(transaction.basescanUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Basescan')),
        );
      }
    }
  }
}

/// Loading Transaction Widget
///
/// Shows animated loading indicator for pending transactions.
class LoadingTransactionWidget extends StatelessWidget {
  final String operation;
  final String? currentStep;
  final double progress;

  const LoadingTransactionWidget({
    super.key,
    required this.operation,
    this.currentStep,
    this.progress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: const Color(0xFF6C63FF).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        operation,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (currentStep != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          currentStep!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (progress > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFF6C63FF),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
