import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/content_purchase_service.dart';
import '../services/content_access_service.dart';
import '../services/web3_service.dart';
import '../services/contract_service.dart';
import '../services/symmetric_crypto_service.dart';
import 'wallet_provider.dart';
import 'content_provider.dart';

// ============================================================================
// SERVICE PROVIDERS
// ============================================================================

/// Provider for ContentPurchaseService
final contentPurchaseServiceProvider = Provider<ContentPurchaseService>((ref) {
  final web3Service = ref.watch(web3ServiceProvider);
  final contractService = ref.watch(contractServiceProvider);

  return ContentPurchaseService(
    web3Service: web3Service,
    contractService: contractService,
  );
});

/// Provider for ContentAccessService
final contentAccessServiceProvider = Provider<ContentAccessService>((ref) {
  final cryptoService = SymmetricCryptoService();

  return ContentAccessService(
    cryptoService: cryptoService,
  );
});

// ============================================================================
// STATE CLASSES
// ============================================================================

/// Purchase state
class PurchaseState {
  final bool isPurchasing;
  final PurchaseStep? currentStep;
  final double progress; // 0.0 to 1.0
  final String? error;
  final PurchaseResult? result;

  const PurchaseState({
    this.isPurchasing = false,
    this.currentStep,
    this.progress = 0.0,
    this.error,
    this.result,
  });

  PurchaseState copyWith({
    bool? isPurchasing,
    PurchaseStep? currentStep,
    double? progress,
    String? error,
    PurchaseResult? result,
  }) {
    return PurchaseState(
      isPurchasing: isPurchasing ?? this.isPurchasing,
      currentStep: currentStep ?? this.currentStep,
      progress: progress ?? this.progress,
      error: error,
      result: result ?? this.result,
    );
  }

  String get stepMessage {
    if (currentStep == null) return '';

    switch (currentStep!) {
      case PurchaseStep.checking:
        return 'Checking balance and permissions...';
      case PurchaseStep.approvingToken:
        return 'Approving VLTC tokens...';
      case PurchaseStep.purchasing:
        return 'Executing purchase transaction...';
      case PurchaseStep.requestingKey:
        return 'Requesting decryption key...';
      case PurchaseStep.complete:
        return 'Purchase complete!';
    }
  }
}

// ============================================================================
// STATE NOTIFIER
// ============================================================================

/// Purchase notifier
///
/// Manages purchase flow state including transaction progress.
class PurchaseNotifier extends StateNotifier<PurchaseState> {
  final ContentPurchaseService purchaseService;
  final ContentAccessService accessService;

  PurchaseNotifier({
    required this.purchaseService,
    required this.accessService,
  }) : super(const PurchaseState());

  /// Purchase content
  ///
  /// Executes the complete purchase flow.
  Future<bool> purchaseContent({
    required BigInt listingId,
    required BigInt contentId,
    required String buyerAddress,
    required String title,
    required String ipfsCid,
    required String category,
    required BigInt fileSize,
    String? description,
  }) async {
    if (state.isPurchasing) return false;

    state = state.copyWith(
      isPurchasing: true,
      error: null,
      result: null,
    );

    try {
      // Execute purchase with progress tracking
      final result = await purchaseService.purchaseContent(
        listingId: listingId,
        buyerAddress: buyerAddress,
        onProgress: (step, progress) {
          state = state.copyWith(
            currentStep: step,
            progress: progress,
          );
        },
      );

      // Add to owned content library
      final ownedContent = OwnedContent(
        contentId: contentId.toString(),
        title: title,
        description: description,
        ipfsCid: ipfsCid,
        category: category,
        fileSize: fileSize,
        acquiredDate: result.purchaseTime,
        encryptedKey: result.reEncryptedKey,
        isOriginalOwner: false,
      );

      await accessService.addToLibrary(content: ownedContent);

      state = state.copyWith(
        isPurchasing: false,
        result: result,
        progress: 1.0,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isPurchasing: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Check if user can purchase
  ///
  /// Verifies wallet connection, balance, etc.
  Future<String?> checkCanPurchase({
    required String userAddress,
    required BigInt price,
  }) async {
    try {
      // Check balance
      final hasBalance = await purchaseService.checkBalance(
        userAddress: userAddress,
        price: price,
      );

      if (!hasBalance) {
        return 'Insufficient VLTC balance';
      }

      return null; // No errors
    } catch (e) {
      return 'Failed to check purchase eligibility: $e';
    }
  }

  /// Reset state
  void reset() {
    state = const PurchaseState();
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for purchase state
final purchaseProvider =
    StateNotifierProvider<PurchaseNotifier, PurchaseState>((ref) {
  final purchaseService = ref.watch(contentPurchaseServiceProvider);
  final accessService = ref.watch(contentAccessServiceProvider);

  return PurchaseNotifier(
    purchaseService: purchaseService,
    accessService: accessService,
  );
});

/// Provider for owned content list
final ownedContentProvider = FutureProvider<List<OwnedContent>>((ref) async {
  final accessService = ref.watch(contentAccessServiceProvider);
  return await accessService.getOwnedContent();
});

/// Provider for single owned content item
final ownedContentItemProvider =
    FutureProvider.family<OwnedContent?, String>((ref, contentId) async {
  final accessService = ref.watch(contentAccessServiceProvider);
  return await accessService.getOwnedContentById(contentId);
});

/// Provider for content by ownership type
final contentByOwnershipProvider =
    FutureProvider<Map<String, List<OwnedContent>>>((ref) async {
  final accessService = ref.watch(contentAccessServiceProvider);
  return await accessService.getContentByOwnership();
});

/// Provider to check if user owns specific content
final ownsContentProvider =
    FutureProvider.family<bool, String>((ref, contentId) async {
  final accessService = ref.watch(contentAccessServiceProvider);
  return await accessService.canAccess(contentId);
});
