import 'package:web3dart/web3dart.dart';
import 'web3_service.dart';
import 'contract_service.dart';

/// Transaction Type Enum
enum TransactionType {
  contentRegistered,
  contentPurchased,
  listingCreated,
  ownershipTransferred,
  other,
}

/// Transaction History Item
class TransactionHistoryItem {
  final String txHash;
  final TransactionType type;
  final DateTime timestamp;
  final String description;
  final BigInt? amount; // For purchases
  final BigInt? contentId;
  final BigInt? listingId;
  final String? fromAddress;
  final String? toAddress;
  final bool isSuccess;

  TransactionHistoryItem({
    required this.txHash,
    required this.type,
    required this.timestamp,
    required this.description,
    this.amount,
    this.contentId,
    this.listingId,
    this.fromAddress,
    this.toAddress,
    this.isSuccess = true,
  });

  /// Get formatted transaction type
  String get typeString {
    switch (type) {
      case TransactionType.contentRegistered:
        return 'Content Registered';
      case TransactionType.contentPurchased:
        return 'Content Purchased';
      case TransactionType.listingCreated:
        return 'Listing Created';
      case TransactionType.ownershipTransferred:
        return 'Ownership Transferred';
      case TransactionType.other:
        return 'Transaction';
    }
  }

  /// Get icon for transaction type
  String get iconName {
    switch (type) {
      case TransactionType.contentRegistered:
        return 'upload';
      case TransactionType.contentPurchased:
        return 'shopping_cart';
      case TransactionType.listingCreated:
        return 'sell';
      case TransactionType.ownershipTransferred:
        return 'swap_horiz';
      case TransactionType.other:
        return 'receipt';
    }
  }

  /// Format amount in VLTC
  String? get formattedAmount {
    if (amount == null) return null;
    final vltc = amount! / BigInt.from(10).pow(18);
    return '${vltc.toStringAsFixed(2)} VLTC';
  }

  /// Short transaction hash
  String get shortTxHash =>
      '${txHash.substring(0, 6)}...${txHash.substring(txHash.length - 4)}';

  Map<String, dynamic> toJson() => {
    'txHash': txHash,
    'type': type.name,
    'typeString': typeString,
    'timestamp': timestamp.toIso8601String(),
    'description': description,
    'amount': amount?.toString(),
    'formattedAmount': formattedAmount,
    'contentId': contentId?.toString(),
    'listingId': listingId?.toString(),
    'fromAddress': fromAddress,
    'toAddress': toAddress,
    'isSuccess': isSuccess,
  };
}

/// Transaction History Service
///
/// Service for querying and displaying transaction history from blockchain events.
class TransactionHistoryService {
  final Web3Service _web3Service;
  final ContractService _contractService;

  TransactionHistoryService(this._web3Service, this._contractService);

  /// Get transaction history for a user address
  ///
  /// Queries blockchain events for transactions involving the user.
  /// This is a simplified version that aggregates different event types.
  Future<List<TransactionHistoryItem>> getTransactionHistory(
    String userAddress, {
    int limit = 50,
  }) async {
    try {
      print('Fetching transaction history for: $userAddress');

      final transactions = <TransactionHistoryItem>[];

      // For MVP, we'll create a simplified history based on:
      // 1. Content registered by user
      // 2. Content purchased by user
      // 3. Listings created by user

      // Get content registered by user
      try {
        final ownedContent = await _web3Service.call(
          contract: _contractService.contentRegistry.contract,
          function: _contractService.contentRegistry.getOwnerContents,
          params: [EthereumAddress.fromHex(userAddress)],
        );

        final contentIds = (ownedContent[0] as List<dynamic>).cast<BigInt>();

        for (final contentId in contentIds.take(limit ~/ 3)) {
          try {
            final contentResult = await _web3Service.call(
              contract: _contractService.contentRegistry.contract,
              function: _contractService.contentRegistry.getContent,
              params: [contentId],
            );

            final timestamp = contentResult[5] as BigInt;
            final timestampSec = timestamp.toInt();

            transactions.add(TransactionHistoryItem(
              txHash: 'content_$contentId', // Placeholder - real tx hash would come from events
              type: TransactionType.contentRegistered,
              timestamp: DateTime.fromMillisecondsSinceEpoch(timestampSec * 1000),
              description: 'Registered content #$contentId on blockchain',
              contentId: contentId,
            ));
          } catch (e) {
            print('Error fetching content $contentId history: $e');
          }
        }
      } catch (e) {
        print('Error fetching registered content history: $e');
      }

      // Sort by timestamp (newest first)
      transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      print('Found ${transactions.length} transactions');
      return transactions;
    } catch (e) {
      print('Error fetching transaction history: $e');
      throw Exception('Failed to fetch transaction history: $e');
    }
  }

  /// Get transaction details from blockchain
  ///
  /// Fetches receipt and details for a specific transaction hash.
  Future<Map<String, dynamic>?> getTransactionDetails(String txHash) async {
    try {
      final receipt = await _web3Service.client.getTransactionReceipt(txHash);

      if (receipt == null) {
        return null;
      }

      return {
        'hash': txHash,
        'blockNumber': receipt.blockNumber.blockNum.toInt(),
        'status': receipt.status ?? false,
        'gasUsed': receipt.gasUsed?.toInt() ?? 0,
        'from': receipt.from?.hex,
        'to': receipt.to?.hex,
      };
    } catch (e) {
      print('Error fetching transaction details: $e');
      return null;
    }
  }
}
