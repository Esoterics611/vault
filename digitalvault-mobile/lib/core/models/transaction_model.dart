/// Transaction status enum
enum TransactionStatus {
  pending,
  confirmed,
  failed,
}

/// Transaction model
class TransactionModel {
  final String hash;
  final TransactionStatus status;
  final String? error;
  final DateTime timestamp;
  final String operation;

  const TransactionModel({
    required this.hash,
    required this.status,
    this.error,
    required this.timestamp,
    required this.operation,
  });

  String get basescanUrl => 'https://sepolia.basescan.org/tx/$hash';

  String get statusText {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.confirmed:
        return 'Confirmed';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }
}
