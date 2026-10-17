import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../services/web3_service.dart';

/// Transaction history state
class TransactionHistoryState {
  final List<TransactionModel> transactions;
  final bool isLoading;
  final String? error;

  const TransactionHistoryState({
    this.transactions = const [],
    this.isLoading = false,
    this.error,
  });

  TransactionHistoryState copyWith({
    List<TransactionModel>? transactions,
    bool? isLoading,
    String? error,
  }) {
    return TransactionHistoryState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Transaction history notifier
class TransactionHistoryNotifier extends StateNotifier<TransactionHistoryState> {
  final Web3Service _web3Service;

  TransactionHistoryNotifier(this._web3Service) : super(const TransactionHistoryState());

  /// Add a new pending transaction
  void addPendingTransaction(String hash, String operation) {
    final transaction = TransactionModel(
      hash: hash,
      status: TransactionStatus.pending,
      timestamp: DateTime.now(),
      operation: operation,
    );

    state = state.copyWith(
      transactions: [transaction, ...state.transactions],
    );

    // Monitor transaction status
    _monitorTransaction(hash);
  }

  /// Monitor transaction status
  Future<void> _monitorTransaction(String hash) async {
    try {
      // Wait for transaction receipt
      final receipt = await _web3Service.waitForReceipt(hash);

      if (receipt != null) {
        // Update transaction status
        final updatedTransactions = state.transactions.map((tx) {
          if (tx.hash == hash) {
            return TransactionModel(
              hash: tx.hash,
              status: receipt.status! ? TransactionStatus.confirmed : TransactionStatus.failed,
              timestamp: tx.timestamp,
              operation: tx.operation,
              error: !receipt.status! ? 'Transaction failed' : null,
            );
          }
          return tx;
        }).toList();

        state = state.copyWith(transactions: updatedTransactions);
      }
    } catch (e) {
      // Update with error
      final updatedTransactions = state.transactions.map((tx) {
        if (tx.hash == hash) {
          return TransactionModel(
            hash: tx.hash,
            status: TransactionStatus.failed,
            timestamp: tx.timestamp,
            operation: tx.operation,
            error: e.toString(),
          );
        }
        return tx;
      }).toList();

      state = state.copyWith(transactions: updatedTransactions);
    }
  }

  /// Clear transaction history
  void clearHistory() {
    state = const TransactionHistoryState();
  }
}

/// Provider for transaction history
final transactionHistoryProvider =
    StateNotifierProvider<TransactionHistoryNotifier, TransactionHistoryState>((ref) {
  return TransactionHistoryNotifier(Web3Service());
});
