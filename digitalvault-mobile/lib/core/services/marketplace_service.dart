import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:web3dart/web3dart.dart';
import '../constants/api_endpoints.dart';
import '../constants/contract_addresses.dart';
import 'web3_service.dart';
import 'contract_service.dart';

/// Marketplace Listing Model
class MarketplaceListing {
  final BigInt listingId;
  final EthereumAddress seller;
  final BigInt contentId;
  final BigInt price;
  final int listingType; // 0=full, 1=time, 2=usage
  final BigInt accessDuration;
  final BigInt maxKeys;
  final BigInt keysIssued;
  final bool active;
  final BigInt timestamp;

  // Additional metadata from content registry
  String? title;
  String? description;
  String? category;
  String? ipfsHash;
  String? thumbnailUrl;

  MarketplaceListing({
    required this.listingId,
    required this.seller,
    required this.contentId,
    required this.price,
    required this.listingType,
    required this.accessDuration,
    required this.maxKeys,
    required this.keysIssued,
    required this.active,
    required this.timestamp,
    this.title,
    this.description,
    this.category,
    this.ipfsHash,
    this.thumbnailUrl,
  });

  /// Convert price from wei to VLTC
  double get priceInVLTC => price.toDouble() / 1e18;

  /// Get listing type as string
  String get listingTypeString {
    switch (listingType) {
      case 0:
        return 'Full Ownership';
      case 1:
        return 'Time Access';
      case 2:
        return 'Usage Access';
      default:
        return 'Unknown';
    }
  }

  /// Format seller address (shortened)
  String get sellerShort =>
      '${seller.hex.substring(0, 6)}...${seller.hex.substring(seller.hex.length - 4)}';

  Map<String, dynamic> toJson() => {
    'listingId': listingId.toString(),
    'seller': seller.hex,
    'contentId': contentId.toString(),
    'price': price.toString(),
    'priceInVLTC': priceInVLTC,
    'listingType': listingType,
    'listingTypeString': listingTypeString,
    'accessDuration': accessDuration.toString(),
    'maxKeys': maxKeys.toString(),
    'keysIssued': keysIssued.toString(),
    'active': active,
    'timestamp': timestamp.toString(),
    'title': title,
    'description': description,
    'category': category,
    'ipfsHash': ipfsHash,
    'thumbnailUrl': thumbnailUrl,
  };
}

/// Marketplace Service
///
/// Handles all marketplace-related operations including:
/// - Loading active listings from blockchain
/// - Fetching metadata from IPFS
/// - Purchasing content
/// - VLTC approval for purchases
class MarketplaceService {
  final Web3Service _web3Service;
  final ContractService _contractService;
  final Dio _dio = Dio();

  MarketplaceService(this._web3Service, this._contractService);

  /// Ensure read-only initialization so Marketplace loads before wallet connects
  Future<void> _ensureInitialized() async {
    _web3Service.ensureReadOnly(chainId: 84532);
    if (!_contractService.isInitialized) {
      await _contractService.initReadOnly(chainId: 84532);
    }
  }

  /// Get all active listings from the blockchain
  Future<List<MarketplaceListing>> getActiveListings() async {
    try {
      await _ensureInitialized();
      // Get active listing IDs from contract
      final result = await _web3Service.call(
        contract: _contractService.marketplaceContract.contract,
        function: _contractService.marketplaceContract.getActiveListings,
        params: [],
      );

      final listingIds = result[0] as List<dynamic>;

      if (listingIds.isEmpty) {
        return [];
      }

      // Fetch details for each listing
      final listings = <MarketplaceListing>[];
      for (var id in listingIds) {
        final listing = await _getListingDetails(id as BigInt);
        if (listing != null && listing.active) {
          listings.add(listing);
        }
      }

      return listings;
    } catch (e) {
      print('Error getting active listings: $e');
      return [];
    }
  }

  /// Get listing details for a specific listing ID
  Future<MarketplaceListing?> _getListingDetails(BigInt listingId) async {
    try {
      // Call listings() function to get listing data
      final result = await _web3Service.call(
        contract: _contractService.marketplaceContract.contract,
        function: _contractService.marketplaceContract.listings,
        params: [listingId],
      );

      // Parse listing data
      final seller = result[0] as EthereumAddress;
      final contentId = result[1] as BigInt;
      final price = result[2] as BigInt;
      final listingType = (result[3] as BigInt).toInt();
      final accessDuration = result[4] as BigInt;
      final maxKeys = result[5] as BigInt;
      final keysIssued = result[6] as BigInt;
      final active = result[7] as bool;
      final timestamp = result[8] as BigInt;

      final listing = MarketplaceListing(
        listingId: listingId,
        seller: seller,
        contentId: contentId,
        price: price,
        listingType: listingType,
        accessDuration: accessDuration,
        maxKeys: maxKeys,
        keysIssued: keysIssued,
        active: active,
        timestamp: timestamp,
      );

      // Fetch content metadata
      await _enrichWithMetadata(listing);

      return listing;
    } catch (e) {
      print('Error getting listing details for ID $listingId: $e');
      return null;
    }
  }

  /// Enrich listing with metadata from ContentRegistry and IPFS
  Future<void> _enrichWithMetadata(MarketplaceListing listing) async {
    try {
      // Get content info from ContentRegistry
      final result = await _web3Service.call(
        contract: _contractService.contentRegistryContract.contract,
        function: _contractService.contentRegistryContract.getContent,
        params: [listing.contentId],
      );

      // Parse content data
      final contentType = (result[6] as BigInt).toInt();

      // Map category
      listing.category = _mapCategory(contentType);

      // Try to fetch metadata from IPFS
      // Note: metadataHash is result[2], but we need the IPFS CID
      // For now, we'll use placeholder data
      // In production, metadata would be stored on IPFS with the hash
      listing.title = 'Content #${listing.contentId}';
      listing.description = 'Creative content available for purchase';

      // If we stored IPFS hash in metadata, fetch it
      // final metadataHash = result[2] as Uint8List;
      // await _fetchIPFSMetadata(listing, metadataHash);

    } catch (e) {
      print('Error enriching metadata for listing ${listing.listingId}: $e');
      // Set defaults
      listing.title = 'Content #${listing.contentId}';
      listing.description = 'Creative content';
      listing.category = 'Unknown';
    }
  }

  /// Map content type integer to category string
  String _mapCategory(int contentType) {
    switch (contentType) {
      case 0:
        return 'Poetry';
      case 1:
        return 'Music';
      case 2:
        return 'Art';
      case 3:
        return 'Video';
      case 4:
        return 'Document';
      default:
        return 'Unknown';
    }
  }

  /// Fetch metadata from IPFS
  ///
  /// In production, metadata would be stored on IPFS and referenced by hash
  Future<void> _fetchIPFSMetadata(MarketplaceListing listing, Uint8List metadataHash) async {
    try {
      // Convert hash to IPFS CID (simplified - actual conversion is complex)
      // final cid = _hashToCID(metadataHash);

      // Fetch from IPFS gateway
      // final response = await _dio.get(
      //   '${ApiEndpoints.ipfsGatewayUrl}/ipfs/$cid',
      // );

      // if (response.statusCode == 200) {
      //   final metadata = response.data;
      //   listing.title = metadata['title'] ?? listing.title;
      //   listing.description = metadata['description'] ?? listing.description;
      //   listing.ipfsHash = cid;
      // }
    } catch (e) {
      print('Error fetching IPFS metadata: $e');
    }
  }

  /// Get listings by seller address
  Future<List<MarketplaceListing>> getListingsBySeller(EthereumAddress seller) async {
    try {
      final result = await _web3Service.call(
        contract: _contractService.marketplaceContract.contract,
        function: _contractService.marketplaceContract.getListingsBySeller,
        params: [seller],
      );

      final listingIds = result[0] as List<dynamic>;

      final listings = <MarketplaceListing>[];
      for (var id in listingIds) {
        final listing = await _getListingDetails(id as BigInt);
        if (listing != null && listing.active) {
          listings.add(listing);
        }
      }

      return listings;
    } catch (e) {
      print('Error getting listings by seller: $e');
      return [];
    }
  }

  /// Filter listings by category
  List<MarketplaceListing> filterByCategory(
    List<MarketplaceListing> listings,
    String category,
  ) {
    if (category.toLowerCase() == 'all') {
      return listings;
    }
    return listings
        .where((l) => l.category?.toLowerCase() == category.toLowerCase())
        .toList();
  }

  /// Get user's VLTC balance
  Future<BigInt> getVLTCBalance(EthereumAddress address) async {
    try {
      final result = await _web3Service.call(
        contract: _contractService.vaultTokenContract.contract,
        function: _contractService.vaultTokenContract.balanceOf,
        params: [address],
      );
      return result[0] as BigInt;
    } catch (e) {
      print('Error getting VLTC balance: $e');
      return BigInt.zero;
    }
  }

  /// Check VLTC allowance for marketplace
  Future<BigInt> getVLTCAllowance(EthereumAddress owner) async {
    try {
      final marketplaceAddress = EthereumAddress.fromHex(
        ContractAddresses.marketplace,
      );

      final result = await _web3Service.call(
        contract: _contractService.vaultTokenContract.contract,
        function: _contractService.vaultTokenContract.allowance,
        params: [owner, marketplaceAddress],
      );
      return result[0] as BigInt;
    } catch (e) {
      print('Error getting VLTC allowance: $e');
      return BigInt.zero;
    }
  }

  /// Approve VLTC spending for marketplace
  Future<String> approveVLTC(BigInt amount) async {
    try {
      final marketplaceAddress = EthereumAddress.fromHex(
        ContractAddresses.marketplace,
      );

      final txHash = await _web3Service.sendContract(
        contract: _contractService.vaultTokenContract.contract,
        function: _contractService.vaultTokenContract.approve,
        parameters: [marketplaceAddress, amount],
      );

      return txHash;
    } catch (e) {
      print('Error approving VLTC: $e');
      rethrow;
    }
  }

  /// Purchase listing with PRE
  ///
  /// This is the main purchase flow for PRE-enabled content
  Future<String> purchaseListingWithPRE({
    required BigInt listingId,
    required Uint8List newEncryptedKey,
    required Uint8List kfragHash,
    required Uint8List newCapsuleHash,
    required Uint8List buyerPublicKey,
    required int threshold,
    required int totalShares,
  }) async {
    try {
      final txHash = await _web3Service.sendContract(
        contract: _contractService.marketplaceContract.contract,
        function: _contractService.marketplaceContract.purchaseListingWithPRE,
        parameters: [
          listingId,
          newEncryptedKey,
          kfragHash,
          newCapsuleHash,
          buyerPublicKey,
          BigInt.from(threshold),
          BigInt.from(totalShares),
        ],
      );

      return txHash;
    } catch (e) {
      print('Error purchasing listing with PRE: $e');
      rethrow;
    }
  }

  /// Purchase listing without PRE
  Future<String> purchaseListing({
    required BigInt listingId,
    required Uint8List newEncryptedKey,
  }) async {
    try {
      final txHash = await _web3Service.sendContract(
        contract: _contractService.marketplaceContract.contract,
        function: _contractService.marketplaceContract.purchaseListing,
        parameters: [listingId, newEncryptedKey],
      );

      return txHash;
    } catch (e) {
      print('Error purchasing listing: $e');
      rethrow;
    }
  }

  /// Calculate platform fee for a given price
  Future<BigInt> calculatePlatformFee(BigInt price) async {
    try {
      final result = await _web3Service.call(
        contract: _contractService.marketplaceContract.contract,
        function: _contractService.marketplaceContract.platformFeePercentage,
        params: [],
      );

      final feeBps = result[0] as BigInt;
      return (price * feeBps) ~/ BigInt.from(10000);
    } catch (e) {
      print('Error calculating platform fee: $e');
      return BigInt.zero;
    }
  }

  /// Estimate gas for purchase transaction
  Future<BigInt> estimatePurchaseGas({
    required BigInt listingId,
    required bool usePRE,
  }) async {
    try {
      // Create dummy parameters for estimation
      final dummyKey = Uint8List(32);

      if (usePRE) {
        final dummyHash = Uint8List(32);
        final dummyPublicKey = Uint8List(64);

        return await _web3Service.estimateGas(
          contract: _contractService.marketplaceContract.contract,
          function: _contractService.marketplaceContract.purchaseListingWithPRE,
          parameters: [
            listingId,
            dummyKey,
            dummyHash,
            dummyHash,
            dummyPublicKey,
            BigInt.from(2),
            BigInt.from(3),
          ],
        );
      } else {
        return await _web3Service.estimateGas(
          contract: _contractService.marketplaceContract.contract,
          function: _contractService.marketplaceContract.purchaseListing,
          parameters: [listingId, dummyKey],
        );
      }
    } catch (e) {
      print('Error estimating gas: $e');
      // Return reasonable default (300k gas)
      return BigInt.from(300000);
    }
  }

  /// Create a new listing
  ///
  /// Lists content for sale on the marketplace.
  ///
  /// Parameters:
  /// - contentId: ID of the content to list
  /// - price: Price in VLTC wei (1 VLTC = 10^18 wei)
  /// - listingType: Type of listing (fullOwnership, timeAccess, usageAccess)
  /// - accessDuration: Duration in seconds for time-based access (0 for full ownership)
  /// - maxKeys: Maximum number of access keys for usage-based (0 for full ownership)
  ///
  /// Returns: Transaction hash of the createListing transaction
  ///
  /// The actual listingId can be extracted from the transaction receipt events.
  Future<BigInt> createListing({
    required BigInt contentId,
    required BigInt price,
    required dynamic listingType, // Can be ListingType enum or int
    required BigInt accessDuration,
    required BigInt maxKeys,
  }) async {
    try {
      // Convert listingType to int if it's an enum
      int listingTypeValue;
      if (listingType is int) {
        listingTypeValue = listingType;
      } else {
        // Assume it's a ListingType enum with a 'value' property
        listingTypeValue = (listingType as dynamic).value as int;
      }

      print('Creating listing: contentId=$contentId, price=$price, type=$listingTypeValue');

      // Send transaction
      final txHash = await _web3Service.sendContract(
        contract: _contractService.marketplaceContract.contract,
        function: _contractService.marketplaceContract.createListing,
        parameters: [
          contentId,
          price,
          BigInt.from(listingTypeValue),
          accessDuration,
          maxKeys,
        ],
      );

      print('Listing creation transaction sent: $txHash');

      // Wait for transaction to be mined
      await _web3Service.waitForReceipt(txHash);

      print('Listing creation transaction confirmed');

      // In production, we would parse the transaction receipt to get the listingId
      // from the ListingCreated event. For now, we'll return a placeholder.
      // The transaction was successful if we got here without exception.

      // Return a success indicator (actual listingId would come from event parsing)
      // For now, just return BigInt.one to indicate success
      return BigInt.one;
    } catch (e) {
      print('Error creating listing: $e');
      throw Exception('Failed to create listing: $e');
    }
  }

  /// Cancel a listing
  ///
  /// Cancels an active listing. Only the seller can cancel their listing.
  ///
  /// Parameters:
  /// - listingId: ID of the listing to cancel
  ///
  /// Returns: Transaction hash
  Future<String> cancelListing(BigInt listingId) async {
    try {
      final txHash = await _web3Service.sendContract(
        contract: _contractService.marketplaceContract.contract,
        function: _contractService.marketplaceContract.cancelListing,
        parameters: [listingId],
      );

      print('Listing cancellation transaction sent: $txHash');
      return txHash;
    } catch (e) {
      print('Error canceling listing: $e');
      throw Exception('Failed to cancel listing: $e');
    }
  }
}
