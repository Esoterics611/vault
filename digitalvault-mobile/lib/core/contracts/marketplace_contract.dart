import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';

/// Listing Type Enum
///
/// Matches the ListingType enum in Marketplace.sol
enum ListingType {
  fullOwnership(0),   // Transfer full ownership of content
  timeAccess(1),      // Temporary access for specified duration
  usageAccess(2);     // Limited number of accesses

  const ListingType(this.value);
  final int value;
}

/// Marketplace Smart Contract Wrapper
///
/// This class provides a type-safe interface to interact with the Marketplace
/// smart contract. It manages content listings, purchases, and PRE-based
/// ownership transfers.
///
/// Contract Address (Base Sepolia): 0xC763Ea95626100C0128c0d28E6DdED873eba91c5
///
/// Key Functions:
/// - createListing: List content for sale
/// - purchaseListing: Purchase content (traditional)
/// - purchaseListingWithPRE: Purchase with PRE re-encryption
/// - cancelListing: Cancel an active listing
/// - getListing: Get listing details
class MarketplaceContract {
  late DeployedContract _contract;
  late String _contractAddress;

  /// Initialize the contract with an address
  Future<void> initialize(String address) async {
    _contractAddress = address;

    // Load ABI from assets
    final abiString = await rootBundle.loadString('assets/abis/Marketplace.json');
    final abiJson = json.decode(abiString);
    final abi = abiJson['abi'] as List<dynamic>;

    _contract = DeployedContract(
      ContractAbi.fromJson(json.encode(abi), 'Marketplace'),
      EthereumAddress.fromHex(_contractAddress),
    );
  }

  /// Get the contract instance
  DeployedContract get contract => _contract;

  /// Get the contract address
  String get address => _contractAddress;

  // ============================================================================
  // VIEW FUNCTIONS (Read-only, no gas cost)
  // ============================================================================

  /// Get listing information
  ///
  /// Returns all details for a specific listing ID.
  ///
  /// Parameters:
  /// - listingId: The unique ID of the listing
  ///
  /// Returns tuple containing:
  /// - seller: Address of the content seller
  /// - contentId: ID of the content being sold
  /// - price: Price in VLTC (wei)
  /// - listingType: Type of listing (0=full, 1=time, 2=usage)
  /// - accessDuration: Duration for time-based access (0 for full ownership)
  /// - maxKeys: Maximum keys for usage-based access (0 for full ownership)
  /// - keysIssued: Number of keys issued so far
  /// - active: Whether listing is active
  /// - timestamp: Listing creation time
  ///
  /// Example:
  /// ```dart
  /// final result = await web3.call(
  ///   contract: contract.contract,
  ///   function: contract.listings,
  ///   params: [listingId],
  /// );
  /// final seller = result[0] as EthereumAddress;
  /// final price = result[2] as BigInt;
  /// final active = result[7] as bool;
  /// ```
  ContractFunction get listings => _contract.function('listings');

  /// Get all active listings
  ///
  /// Returns an array of active listing IDs.
  ///
  /// Returns: Array of listing IDs (uint256[])
  ///
  /// Note: May be gas-intensive for large numbers of listings.
  /// Consider using off-chain indexing for production.
  ///
  /// Example:
  /// ```dart
  /// final result = await web3.call(
  ///   contract: contract.contract,
  ///   function: contract.getActiveListings,
  ///   params: [],
  /// );
  /// final listingIds = result[0] as List<dynamic>;
  /// ```
  ContractFunction get getActiveListings => _contract.function('getActiveListings');

  /// Get all listings by a seller
  ///
  /// Returns an array of listing IDs created by the specified seller.
  ///
  /// Parameters:
  /// - seller: Address of the seller
  ///
  /// Returns: Array of listing IDs (uint256[])
  ///
  /// Example:
  /// ```dart
  /// final result = await web3.call(
  ///   contract: contract.contract,
  ///   function: contract.getListingsBySeller,
  ///   params: [sellerAddress],
  /// );
  /// final listingIds = result[0] as List<dynamic>;
  /// ```
  ContractFunction get getListingsBySeller => _contract.function('getListingsBySeller');

  /// Get the current listing ID counter
  ///
  /// Returns the total number of listings ever created.
  ///
  /// Example:
  /// ```dart
  /// final result = await web3.call(
  ///   contract: contract.contract,
  ///   function: contract.listingIdCounter,
  ///   params: [],
  /// );
  /// final totalListings = result[0] as BigInt;
  /// ```
  ContractFunction get listingIdCounter => _contract.function('listingIdCounter');

  /// Get the platform fee percentage
  ///
  /// Returns the fee percentage (in basis points, e.g., 250 = 2.5%).
  ///
  /// Example:
  /// ```dart
  /// final result = await web3.call(
  ///   contract: contract.contract,
  ///   function: contract.platformFeePercentage,
  ///   params: [],
  /// );
  /// final feeBps = result[0] as BigInt; // e.g., 250 = 2.5%
  /// ```
  ContractFunction get platformFeePercentage => _contract.function('platformFeePercentage');

  /// Get ContentRegistry contract address
  ///
  /// Returns the address of the ContentRegistry contract used by this marketplace.
  ContractFunction get contentRegistry => _contract.function('contentRegistry');

  /// Get ReKeyRegistry contract address
  ///
  /// Returns the address of the ReKeyRegistry contract used for PRE operations.
  ContractFunction get reKeyRegistry => _contract.function('reKeyRegistry');

  /// Get VaultToken contract address
  ///
  /// Returns the address of the VaultToken (VLTC) contract used for payments.
  ContractFunction get vaultToken => _contract.function('vaultToken');

  // ============================================================================
  // TRANSACTION FUNCTIONS (Write operations, require gas)
  // ============================================================================

  /// Create a new listing
  ///
  /// Lists content for sale on the marketplace.
  ///
  /// Parameters:
  /// - contentId: ID of the content to list (must own it)
  /// - price: Price in VLTC wei (1 VLTC = 10^18 wei)
  /// - listingType: Type of listing (0=full, 1=time, 2=usage)
  /// - accessDuration: Duration in seconds (for time-based) or 0
  /// - maxKeys: Maximum keys (for usage-based) or 0
  ///
  /// Returns: New listing ID (uint256)
  ///
  /// Emits: ListingCreated(listingId, seller, contentId, price, timestamp)
  ///
  /// Requirements:
  /// - Caller must own the content
  /// - Content must be active
  /// - Price must be > 0
  /// - For time-based: accessDuration must be > 0
  /// - For usage-based: maxKeys must be > 0
  ///
  /// Example:
  /// ```dart
  /// // Create full ownership listing for 100 VLTC
  /// final price = BigInt.from(100) * BigInt.from(10).pow(18);
  ///
  /// final tx = await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: contract.contract,
  ///     function: contract.createListing,
  ///     parameters: [
  ///       BigInt.from(contentId),
  ///       price,
  ///       ListingType.fullOwnership.value,
  ///       BigInt.zero,  // accessDuration (0 for full ownership)
  ///       BigInt.zero,  // maxKeys (0 for full ownership)
  ///     ],
  ///   ),
  ///   chainId: 84532,
  /// );
  /// ```
  ContractFunction get createListing => _contract.function('createListing');

  /// Purchase listing WITHOUT PRE
  ///
  /// Purchase content with traditional ownership transfer.
  ///
  /// Parameters:
  /// - listingId: ID of the listing to purchase
  /// - newEncryptedKey: AES key encrypted with buyer's public key
  ///
  /// Emits: ListingPurchased(listingId, buyer, contentId, price)
  ///
  /// Requirements:
  /// - Listing must be active
  /// - Caller cannot be the seller
  /// - Caller must have approved VLTC spending (use VaultToken.approve)
  /// - Content must not use PRE
  ///
  /// Example:
  /// ```dart
  /// // First, approve VLTC spending
  /// final approveTx = await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: vaultTokenContract.contract,
  ///     function: vaultTokenContract.approve,
  ///     parameters: [marketplaceAddress, price],
  ///   ),
  /// );
  /// await approveTx.wait();
  ///
  /// // Then purchase
  /// final purchaseTx = await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: contract.contract,
  ///     function: contract.purchaseListing,
  ///     parameters: [
  ///       BigInt.from(listingId),
  ///       newEncryptedKey,  // AES key encrypted for buyer
  ///     ],
  ///   ),
  /// );
  /// ```
  ContractFunction get purchaseListing => _contract.function('purchaseListing');

  /// Purchase listing WITH PRE
  ///
  /// Purchase PRE-enabled content with secure re-encryption.
  ///
  /// Parameters:
  /// - listingId: ID of the listing to purchase
  /// - newEncryptedKey: AES key encrypted with buyer's public key
  /// - kfragHash: Hash of the key fragments for re-encryption
  /// - newCapsuleHash: Hash of the re-encrypted capsule
  /// - buyerPublicKey: Buyer's Umbral public key
  /// - threshold: Minimum key fragments needed (e.g., 2)
  /// - totalShares: Total key fragments created (e.g., 3)
  ///
  /// Emits:
  /// - ListingPurchased(listingId, buyer, contentId, price)
  /// - GrantCreated(contentId, seller, buyer, kfragHash)
  ///
  /// Requirements:
  /// - All requirements from purchaseListing
  /// - Content must use PRE
  /// - kfragHash must not be zero
  /// - newCapsuleHash must not be zero
  /// - buyerPublicKey must not be empty
  /// - threshold must be <= totalShares
  ///
  /// Example:
  /// ```dart
  /// // After getting PRE parameters from backend
  /// final kfragHash = keccak256(kfrags);
  /// final newCapsuleHash = keccak256(reencryptedCapsule);
  ///
  /// // First approve VLTC
  /// await approveVLTC(marketplaceAddress, price);
  ///
  /// // Then purchase with PRE
  /// final tx = await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: contract.contract,
  ///     function: contract.purchaseListingWithPRE,
  ///     parameters: [
  ///       BigInt.from(listingId),
  ///       newEncryptedKey,
  ///       kfragHash,
  ///       newCapsuleHash,
  ///       buyerPublicKey,
  ///       BigInt.from(2),  // threshold (2-of-3)
  ///       BigInt.from(3),  // totalShares
  ///     ],
  ///   ),
  ///   chainId: 84532,
  /// );
  /// ```
  ContractFunction get purchaseListingWithPRE => _contract.function('purchaseListingWithPRE');

  /// Cancel a listing
  ///
  /// Cancels an active listing. Can only be called by the seller.
  ///
  /// Parameters:
  /// - listingId: ID of the listing to cancel
  ///
  /// Emits: ListingCancelled(listingId, seller)
  ///
  /// Requirements:
  /// - Caller must be the seller
  /// - Listing must be active
  ///
  /// Example:
  /// ```dart
  /// final tx = await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: contract.contract,
  ///     function: contract.cancelListing,
  ///     parameters: [BigInt.from(listingId)],
  ///   ),
  /// );
  /// ```
  ContractFunction get cancelListing => _contract.function('cancelListing');

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Calculate platform fee for a price
  ///
  /// Helper function to calculate the platform fee for a given price.
  ///
  /// Example:
  /// ```dart
  /// final fee = MarketplaceContract.calculateFee(price, feeBps);
  /// final sellerAmount = price - fee;
  /// ```
  static BigInt calculateFee(BigInt price, BigInt feeBasisPoints) {
    return (price * feeBasisPoints) ~/ BigInt.from(10000);
  }

  /// Parse listing info from contract call result
  ///
  /// Helper to parse the tuple returned by listings().
  ///
  /// Example:
  /// ```dart
  /// final result = await web3.call(...);
  /// final info = MarketplaceContract.parseListingInfo(result);
  /// ```
  static Map<String, dynamic> parseListingInfo(List<dynamic> result) {
    return {
      'seller': result[0] as EthereumAddress,
      'contentId': result[1] as BigInt,
      'price': result[2] as BigInt,
      'listingType': result[3] as BigInt,
      'accessDuration': result[4] as BigInt,
      'maxKeys': result[5] as BigInt,
      'keysIssued': result[6] as BigInt,
      'active': result[7] as bool,
      'timestamp': result[8] as BigInt,
    };
  }

  /// Format listing type as string
  ///
  /// Convert listing type enum to readable string.
  static String formatListingType(BigInt listingType) {
    switch (listingType.toInt()) {
      case 0:
        return 'Full Ownership';
      case 1:
        return 'Time-Based Access';
      case 2:
        return 'Usage-Based Access';
      default:
        return 'Unknown';
    }
  }
}
