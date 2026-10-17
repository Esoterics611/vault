import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';

/// Content Category Enum
///
/// Matches the ContentType enum in ContentRegistry.sol
enum ContentCategory {
  journal(0),      // Written content, poems
  music(1),       // Audio files, songs
  art(2),         // Images, digital art
  video(3),       // Video files
  document(4);    // Documents, PDFs

  const ContentCategory(this.value);
  final int value;
}

/// Access Model Enum
///
/// Matches the AccessModel enum in ContentRegistry.sol
enum AccessModel {
  traditional(0),  // Traditional ownership transfer
  pre(1);         // Proxy Re-Encryption based access

  const AccessModel(this.value);
  final int value;
}

/// ContentRegistry Smart Contract Wrapper
///
/// This class provides a type-safe interface to interact with the ContentRegistry
/// smart contract. It manages content registration, ownership, and PRE (Proxy
/// Re-Encryption) metadata.
///
/// Contract Address (Base Sepolia): 0xd469e2AA709bb01ab409eBb762c655FC641C41f0
///
/// Key Functions:
/// - registerContent: Register content without PRE
/// - registerContentWithPRE: Register content with PRE support
/// - getContent: Get content metadata
/// - transferOwnership: Transfer content ownership
/// - transferOwnershipWithPRE: Transfer with PRE re-encryption
class ContentRegistryContract {
  late DeployedContract _contract;
  late String _contractAddress;

  /// Initialize the contract with an address
  Future<void> initialize(String address) async {
    _contractAddress = address;

    // Load ABI from assets
    final abiString = await rootBundle.loadString('assets/abis/ContentRegistry.json');
    final abiJson = json.decode(abiString);
    final abi = abiJson['abi'] as List<dynamic>;

    _contract = DeployedContract(
      ContractAbi.fromJson(json.encode(abi), 'ContentRegistry'),
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

  /// Get content information
  ///
  /// Returns all metadata for a specific content ID.
  ///
  /// Parameters:
  /// - contentId: The unique ID of the content
  ///
  /// Returns tuple containing:
  /// - owner: Current owner address
  /// - contentHash: Hash of the encrypted content
  /// - metadataHash: Hash of the metadata
  /// - encryptedKey: Encrypted AES key for content
  /// - fileSize: Size of the content file in bytes
  /// - timestamp: Registration timestamp
  /// - contentType: Category (journal, music, etc.)
  /// - accessModel: Traditional or PRE
  /// - isActive: Whether content is active
  ///
  /// Example:
  /// ```dart
  /// final result = await web3.call(
  ///   contract: contract.contract,
  ///   function: contract.getContent,
  ///   params: [contentId],
  /// );
  /// final owner = result[0] as EthereumAddress;
  /// final contentHash = result[1] as Uint8List;
  /// ```
  ContractFunction get getContent => _contract.function('getContent');

  /// Get PRE (Proxy Re-Encryption) data for content
  ///
  /// Returns PRE-specific metadata for content that uses PRE.
  ///
  /// Parameters:
  /// - contentId: The unique ID of the content
  ///
  /// Returns tuple containing:
  /// - capsuleHash: Hash of the encrypted capsule
  /// - ownerPublicKey: Owner's public key for re-encryption
  ///
  /// Requirements:
  /// - Content must use PRE (accessModel = 1)
  ///
  /// Example:
  /// ```dart
  /// final result = await web3.call(
  ///   contract: contract.contract,
  ///   function: contract.getPREData,
  ///   params: [contentId],
  /// );
  /// final capsuleHash = result[0] as Uint8List;
  /// final publicKey = result[1] as Uint8List;
  /// ```
  ContractFunction get getPREData => _contract.function('getPREData');

  /// Get all content IDs owned by an address
  ///
  /// Returns an array of content IDs owned by the specified address.
  ///
  /// Parameters:
  /// - owner: The address to query
  ///
  /// Returns: Array of content IDs (uint256[])
  ///
  /// Example:
  /// ```dart
  /// final result = await web3.call(
  ///   contract: contract.contract,
  ///   function: contract.getOwnerContents,
  ///   params: [userAddress],
  /// );
  /// final contentIds = result[0] as List<dynamic>;
  /// ```
  ContractFunction get getOwnerContents => _contract.function('getOwnerContents');

  /// Get full content info by ID
  ///
  /// Returns the full Content struct for a given content ID.
  /// The struct contains: contentHash, metadataHash, owner, contentType, accessModel,
  /// isActive, capsuleVersion, usesPRE, creator, createdAt, fileSize, encryptedKey, viewCount, capsuleHash
  ///
  /// Example:
  /// ```dart
  /// final result = await web3.call(
  ///   contract: contract.contract,
  ///   function: contract.getContentInfo,
  ///   params: [contentId],
  /// );
  /// final contentData = result[0]; // Content struct
  /// final isActive = contentData[5] as bool;
  /// ```
  ContractFunction get getContentInfo => _contract.function('getContentInfo');

  /// Get creator's content IDs
  ///
  /// Returns an array of content IDs created by the specified address.
  ///
  /// Parameters:
  /// - creator: The address to query
  ///
  /// Returns: Array of content IDs (uint256[])
  ContractFunction get getCreatorContents => _contract.function('getCreatorContents');

  // ============================================================================
  // TRANSACTION FUNCTIONS (Write operations, require gas)
  // ============================================================================

  /// Register content WITHOUT Proxy Re-Encryption
  ///
  /// Registers content with traditional encryption where the owner holds the key.
  ///
  /// Parameters:
  /// - contentHash: keccak256 hash of encrypted content (bytes32)
  /// - metadataHash: keccak256 hash of metadata (bytes32)
  /// - encryptedKey: AES key encrypted with owner's public key (bytes)
  /// - fileSize: Size of content file in bytes (uint256)
  /// - contentType: Category enum value (0-4)
  /// - accessModel: Access model enum value (0=traditional, 1=PRE)
  ///
  /// Returns: New content ID (uint256)
  ///
  /// Emits: ContentRegistered(contentId, owner, contentHash, timestamp)
  ///
  /// Requirements:
  /// - contentHash must not be zero
  /// - metadataHash must not be zero
  /// - encryptedKey must not be empty
  /// - fileSize must be > 0
  ///
  /// Example:
  /// ```dart
  /// final contentHash = keccak256(encryptedContent);
  /// final metadataHash = keccak256(metadata);
  /// final encryptedKey = encryptAESKey(aesKey, ownerPublicKey);
  ///
  /// final tx = await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: contract.contract,
  ///     function: contract.registerContent,
  ///     parameters: [
  ///       contentHash,
  ///       metadataHash,
  ///       encryptedKey,
  ///       BigInt.from(fileSize),
  ///       ContentCategory.journal.value,
  ///       AccessModel.traditional.value,
  ///     ],
  ///   ),
  /// );
  /// ```
  ContractFunction get registerContent => _contract.function('registerContent');

  /// Register content WITH Proxy Re-Encryption
  ///
  /// Registers content with PRE support, allowing secure ownership transfer
  /// without revealing the original encryption key.
  ///
  /// Parameters:
  /// - contentHash: keccak256 hash of encrypted content (bytes32)
  /// - metadataHash: keccak256 hash of metadata (bytes32)
  /// - encryptedKey: AES key encrypted with owner's public key (bytes)
  /// - fileSize: Size of content file in bytes (uint256)
  /// - contentType: Category enum value (0-4)
  /// - accessModel: Access model enum value (should be 1 for PRE)
  /// - capsuleHash: keccak256 hash of PRE capsule (bytes32)
  /// - ownerPublicKey: Owner's Umbral public key (bytes)
  ///
  /// Returns: New content ID (uint256)
  ///
  /// Emits:
  /// - ContentRegistered(contentId, owner, contentHash, timestamp)
  /// - PREDataStored(contentId, capsuleHash)
  ///
  /// Requirements:
  /// - All requirements from registerContent
  /// - capsuleHash must not be zero
  /// - ownerPublicKey must not be empty
  ///
  /// Example:
  /// ```dart
  /// // After encrypting content with AES
  /// final contentHash = keccak256(encryptedContent);
  /// final metadataHash = keccak256(metadata);
  /// final encryptedKey = encryptAESKey(aesKey, ownerPublicKey);
  /// final capsuleHash = keccak256(preCapsule);
  ///
  /// final tx = await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: contract.contract,
  ///     function: contract.registerContentWithPRE,
  ///     parameters: [
  ///       contentHash,              // bytes32
  ///       metadataHash,             // bytes32
  ///       encryptedKey,             // bytes
  ///       BigInt.from(fileSize),    // uint256
  ///       ContentCategory.art.value,      // uint8 (0-4)
  ///       AccessModel.pre.value,          // uint8 (1 for PRE)
  ///       capsuleHash,              // bytes32
  ///       ownerPublicKey,           // bytes
  ///     ],
  ///   ),
  ///   chainId: 84532, // Base Sepolia
  /// );
  ///
  /// // Wait for confirmation
  /// final receipt = await tx.wait();
  /// final contentId = receipt.logs[0].topics[1]; // Extract from event
  /// ```
  ContractFunction get registerContentWithPRE => _contract.function('registerContentWithPRE');

  /// Transfer content ownership WITHOUT PRE
  ///
  /// Transfers ownership of content to a new owner. Used for traditional
  /// encrypted content.
  ///
  /// Parameters:
  /// - contentId: ID of the content to transfer
  /// - newOwner: Address of the new owner
  /// - newEncryptedKey: AES key encrypted with new owner's public key
  /// - price: Price paid for the transfer (for tracking)
  ///
  /// Emits: ContentOwnershipTransferred(contentId, oldOwner, newOwner, price)
  ///
  /// Requirements:
  /// - Caller must be current owner or trusted marketplace
  /// - Content must not use PRE
  /// - newOwner cannot be zero address
  ContractFunction get transferOwnership => _contract.function('transferOwnership');

  /// Transfer content ownership WITH PRE
  ///
  /// Transfers ownership of PRE-enabled content with re-encryption.
  ///
  /// Parameters:
  /// - contentId: ID of the content to transfer
  /// - newOwner: Address of the new owner
  /// - newEncryptedKey: AES key encrypted for new owner
  /// - price: Price paid for the transfer
  /// - newCapsuleHash: Hash of re-encrypted capsule
  /// - newPublicKey: New owner's Umbral public key
  ///
  /// Emits: ContentOwnershipTransferred(contentId, oldOwner, newOwner, price)
  ///
  /// Requirements:
  /// - Caller must be current owner or trusted marketplace
  /// - Content must use PRE
  /// - newCapsuleHash must not be zero
  /// - newPublicKey must not be empty
  ContractFunction get transferOwnershipWithPRE =>
      _contract.function('transferOwnershipWithPRE');

  /// Deactivate content
  ///
  /// Marks content as inactive. Can only be called by owner.
  ///
  /// Parameters:
  /// - contentId: ID of the content to deactivate
  ///
  /// Emits: ContentDeactivated(contentId, owner)
  ///
  /// Requirements:
  /// - Caller must be owner
  /// - Content must be active
  ContractFunction get deactivateContent => _contract.function('deactivateContent');

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Create content hash from bytes
  ///
  /// Helper function to create a keccak256 hash for content.
  ///
  /// Example:
  /// ```dart
  /// final contentBytes = Uint8List.fromList(encryptedContent);
  /// final hash = ContentRegistryContract.createHash(contentBytes);
  /// ```
  static Uint8List createHash(Uint8List data) {
    // Note: In production, use proper keccak256 implementation
    // For now, this is a placeholder
    return Uint8List(32); // Replace with actual keccak256
  }

  /// Parse content info from contract call result
  ///
  /// Helper to parse the tuple returned by getContent().
  ///
  /// Example:
  /// ```dart
  /// final result = await web3.call(...);
  /// final info = ContentRegistryContract.parseContentInfo(result);
  /// ```
  static Map<String, dynamic> parseContentInfo(List<dynamic> result) {
    return {
      'owner': result[0] as EthereumAddress,
      'contentHash': result[1] as Uint8List,
      'metadataHash': result[2] as Uint8List,
      'encryptedKey': result[3] as Uint8List,
      'fileSize': result[4] as BigInt,
      'timestamp': result[5] as BigInt,
      'contentType': result[6] as BigInt,
      'accessModel': result[7] as BigInt,
      'isActive': result[8] as bool,
    };
  }
}
