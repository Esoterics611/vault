import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loading state model for different operations
class LoadingState {
  final Map<String, bool> operations;

  const LoadingState({this.operations = const {}});

  bool isLoading(String operation) => operations[operation] ?? false;

  LoadingState copyWith({required Map<String, bool> operations}) {
    return LoadingState(operations: operations);
  }
}

/// Loading state notifier
class LoadingNotifier extends StateNotifier<LoadingState> {
  LoadingNotifier() : super(const LoadingState());

  /// Start loading for a specific operation
  void startLoading(String operation) {
    final newOperations = Map<String, bool>.from(state.operations);
    newOperations[operation] = true;
    state = LoadingState(operations: newOperations);
  }

  /// Stop loading for a specific operation
  void stopLoading(String operation) {
    final newOperations = Map<String, bool>.from(state.operations);
    newOperations[operation] = false;
    state = LoadingState(operations: newOperations);
  }

  /// Check if any operation is loading
  bool get isAnyLoading => state.operations.values.any((loading) => loading);
}

/// Provider for global loading state
final loadingProvider = StateNotifierProvider<LoadingNotifier, LoadingState>((ref) {
  return LoadingNotifier();
});

/// Common operation keys
class LoadingOperations {
  static const String walletConnection = 'wallet_connection';
  static const String balanceRefresh = 'balance_refresh';
  static const String contentUpload = 'content_upload';
  static const String marketplaceFetch = 'marketplace_fetch';
  static const String daoFetch = 'dao_fetch';
  static const String transaction = 'transaction';
}
