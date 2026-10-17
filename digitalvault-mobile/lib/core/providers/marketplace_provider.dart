import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3dart/web3dart.dart';
import '../services/marketplace_service.dart';
import '../services/web3_service.dart';
import '../services/contract_service.dart';
import 'wallet_provider.dart';

/// Marketplace State
class MarketplaceState {
  final List<MarketplaceListing> listings;
  final bool isLoading;
  final String? error;
  final String selectedCategory;
  final String searchQuery;
  final bool showFreeOnly;
  final bool showPaidOnly;
  final MarketplaceListing? selectedListing;

  /// Purchase flow state
  final bool isPurchasing;
  final double purchaseProgress; // 0.0 to 1.0
  final String? purchaseError;
  final String? currentStep;

  MarketplaceState({
    this.listings = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategory = 'all',
    this.searchQuery = '',
    this.showFreeOnly = false,
    this.showPaidOnly = false,
    this.selectedListing,
    this.isPurchasing = false,
    this.purchaseProgress = 0.0,
    this.purchaseError,
    this.currentStep,
  });

  MarketplaceState copyWith({
    List<MarketplaceListing>? listings,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    String? searchQuery,
    bool? showFreeOnly,
    bool? showPaidOnly,
    MarketplaceListing? selectedListing,
    bool? isPurchasing,
    double? purchaseProgress,
    String? purchaseError,
    String? currentStep,
  }) {
    return MarketplaceState(
      listings: listings ?? this.listings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      showFreeOnly: showFreeOnly ?? this.showFreeOnly,
      showPaidOnly: showPaidOnly ?? this.showPaidOnly,
      selectedListing: selectedListing ?? this.selectedListing,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      purchaseProgress: purchaseProgress ?? this.purchaseProgress,
      purchaseError: purchaseError,
      currentStep: currentStep,
    );
  }

  /// Get filtered listings by category, search, and price
  List<MarketplaceListing> get filteredListings {
    var filtered = listings;

    // Category filter
    if (selectedCategory.toLowerCase() != 'all') {
      filtered = filtered
          .where((l) => l.category?.toLowerCase() == selectedCategory.toLowerCase())
          .toList();
    }

    // Search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((l) {
        final title = l.title?.toLowerCase() ?? '';
        final description = l.description?.toLowerCase() ?? '';
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    // Price filter
    if (showFreeOnly) {
      filtered = filtered.where((l) => l.price == BigInt.zero).toList();
    } else if (showPaidOnly) {
      filtered = filtered.where((l) => l.price > BigInt.zero).toList();
    }

    return filtered;
  }

  /// Check if any filters are active
  bool get hasActiveFilters {
    return selectedCategory.toLowerCase() != 'all' ||
        searchQuery.isNotEmpty ||
        showFreeOnly ||
        showPaidOnly;
  }
}

/// Marketplace Notifier
class MarketplaceNotifier extends StateNotifier<MarketplaceState> {
  final MarketplaceService _marketplaceService;
  final Web3Service _web3Service;
  final Ref _ref;

  MarketplaceNotifier(
    this._marketplaceService,
    this._web3Service,
    this._ref,
  ) : super(MarketplaceState());

  /// Load all active listings
  Future<void> loadListings() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      final listings = await _marketplaceService.getActiveListings();

      state = state.copyWith(
        listings: listings,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load listings: $e',
      );
    }
  }

  /// Set selected category filter
  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  /// Set search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Toggle free-only filter
  void toggleFreeOnly() {
    state = state.copyWith(
      showFreeOnly: !state.showFreeOnly,
      showPaidOnly: false, // Mutually exclusive with paid-only
    );
  }

  /// Toggle paid-only filter
  void togglePaidOnly() {
    state = state.copyWith(
      showPaidOnly: !state.showPaidOnly,
      showFreeOnly: false, // Mutually exclusive with free-only
    );
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(
      selectedCategory: 'all',
      searchQuery: '',
      showFreeOnly: false,
      showPaidOnly: false,
    );
  }

  /// Select a listing for viewing details
  void selectListing(MarketplaceListing listing) {
    state = state.copyWith(selectedListing: listing);
  }

  /// Clear selected listing
  void clearSelectedListing() {
    state = state.copyWith(selectedListing: null);
  }

  /// Purchase content (with PRE)
  ///
  /// Full purchase flow:
  /// 1. Check VLTC balance
  /// 2. Check/approve VLTC allowance
  /// 3. Generate buyer's PRE keys (if PRE content)
  /// 4. Request re-encryption from PRE proxy
  /// 5. Submit purchase transaction
  /// 6. Wait for confirmation
  Future<bool> purchaseContent(MarketplaceListing listing) async {
    state = state.copyWith(
      isPurchasing: true,
      purchaseProgress: 0.0,
      purchaseError: null,
      currentStep: 'Checking balance...',
    );

    try {
      // Get user address
      final walletState = _ref.read(walletProvider);
      if (!walletState.isConnected) {
        throw Exception('Wallet not connected');
      }

      final userAddress = EthereumAddress.fromHex(walletState.address!);

      // Step 1: Check VLTC balance (10%)
      state = state.copyWith(
        purchaseProgress: 0.1,
        currentStep: 'Checking VLTC balance...',
      );

      final balance = await _marketplaceService.getVLTCBalance(userAddress);
      if (balance < listing.price) {
        throw Exception(
          'Insufficient VLTC balance. Need ${listing.priceInVLTC} VLTC',
        );
      }

      // Step 2: Check allowance (20%)
      state = state.copyWith(
        purchaseProgress: 0.2,
        currentStep: 'Checking VLTC allowance...',
      );

      final allowance = await _marketplaceService.getVLTCAllowance(userAddress);

      // Step 3: Approve VLTC if needed (30%)
      if (allowance < listing.price) {
        state = state.copyWith(
          purchaseProgress: 0.3,
          currentStep: 'Approving VLTC spending...',
        );

        final approveTxHash = await _marketplaceService.approveVLTC(
          listing.price * BigInt.from(2), // Approve 2x for future purchases
        );

        // Wait for approval confirmation
        state = state.copyWith(
          purchaseProgress: 0.4,
          currentStep: 'Waiting for approval confirmation...',
        );

        await _web3Service.waitForReceipt(approveTxHash);
      }

      // Step 4: Generate buyer's PRE keys (50%)
      state = state.copyWith(
        purchaseProgress: 0.5,
        currentStep: 'Generating encryption keys...',
      );

      // TODO: Call PRE proxy to generate buyer keys
      // For now, use dummy data
      final buyerPublicKey = List<int>.filled(64, 0);
      final newEncryptedKey = List<int>.filled(32, 0);

      // Step 5: Request re-encryption (60%)
      state = state.copyWith(
        purchaseProgress: 0.6,
        currentStep: 'Requesting re-encryption...',
      );

      // TODO: Call PRE proxy to get kfrags and re-encrypted capsule
      // For now, use dummy data
      final kfragHash = List<int>.filled(32, 0);
      final newCapsuleHash = List<int>.filled(32, 0);

      // Step 6: Submit purchase transaction (70%)
      state = state.copyWith(
        purchaseProgress: 0.7,
        currentStep: 'Submitting purchase transaction...',
      );

      final purchaseTxHash = await _marketplaceService.purchaseListingWithPRE(
        listingId: listing.listingId,
        newEncryptedKey: Uint8List.fromList(newEncryptedKey),
        kfragHash: Uint8List.fromList(kfragHash),
        newCapsuleHash: Uint8List.fromList(newCapsuleHash),
        buyerPublicKey: Uint8List.fromList(buyerPublicKey),
        threshold: 2,
        totalShares: 3,
      );

      // Step 7: Wait for confirmation (90%)
      state = state.copyWith(
        purchaseProgress: 0.9,
        currentStep: 'Waiting for transaction confirmation...',
      );

      final receipt = await _web3Service.waitForReceipt(purchaseTxHash);

      // Check if transaction succeeded
      if (receipt?.status != true) {
        throw Exception('Transaction failed on blockchain');
      }

      // Step 8: Complete (100%)
      state = state.copyWith(
        isPurchasing: false,
        purchaseProgress: 1.0,
        currentStep: 'Purchase complete!',
        purchaseError: null,
      );

      // Refresh listings
      await loadListings();

      // Refresh wallet balance
      _ref.read(walletProvider.notifier).refreshBalances();

      return true;
    } catch (e) {
      state = state.copyWith(
        isPurchasing: false,
        purchaseError: e.toString(),
        currentStep: null,
      );
      return false;
    }
  }

  /// Reset purchase state
  void resetPurchaseState() {
    state = state.copyWith(
      isPurchasing: false,
      purchaseProgress: 0.0,
      purchaseError: null,
      currentStep: null,
    );
  }

  /// Refresh listings
  Future<void> refresh() async {
    await loadListings();
  }
}

/// Marketplace Service Provider
final marketplaceServiceProvider = Provider<MarketplaceService>((ref) {
  final web3Service = ref.watch(web3ServiceProvider);
  final contractService = ref.watch(contractServiceProvider);

  return MarketplaceService(
    web3Service,
    contractService,
  );
});

/// Marketplace Provider
final marketplaceProvider =
    StateNotifierProvider<MarketplaceNotifier, MarketplaceState>((ref) {
  final web3Service = ref.watch(web3ServiceProvider);
  final marketplaceService = ref.watch(marketplaceServiceProvider);

  return MarketplaceNotifier(
    marketplaceService,
    web3Service,
    ref,
  );
});

// web3ServiceProvider and contractServiceProvider are now imported from wallet_provider.dart
