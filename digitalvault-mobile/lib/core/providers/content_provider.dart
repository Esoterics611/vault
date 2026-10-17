import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import '../services/web3_service.dart';
import '../services/encryption_service.dart';
import '../services/contract_service.dart';
import '../services/content_browse_service.dart';
import '../contracts/content_registry_contract.dart';
import '../contracts/marketplace_contract.dart';
import '../contracts/vault_token_contract.dart';
import 'transaction_provider.dart';
import 'wallet_provider.dart';

/// Content Upload State Model
///
/// Tracks the state of content upload and blockchain registration.
class ContentUploadState {
  final String? contentId;
  final String? ipfsHash;
  final String? transactionHash;
  final String? listingId;
  final bool isUploading;
  final bool isRegistering;
  final bool isListing;
  final double uploadProgress;
  final String? error;
  final String? currentStep;

  const ContentUploadState({
    this.contentId,
    this.ipfsHash,
    this.transactionHash,
    this.listingId,
    this.isUploading = false,
    this.isRegistering = false,
    this.isListing = false,
    this.uploadProgress = 0.0,
    this.error,
    this.currentStep,
  });

  ContentUploadState copyWith({
    String? contentId,
    String? ipfsHash,
    String? transactionHash,
    String? listingId,
    bool? isUploading,
    bool? isRegistering,
    bool? isListing,
    double? uploadProgress,
    String? error,
    String? currentStep,
  }) {
    return ContentUploadState(
      contentId: contentId ?? this.contentId,
      ipfsHash: ipfsHash ?? this.ipfsHash,
      transactionHash: transactionHash ?? this.transactionHash,
      listingId: listingId ?? this.listingId,
      isUploading: isUploading ?? this.isUploading,
      isRegistering: isRegistering ?? this.isRegistering,
      isListing: isListing ?? this.isListing,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  bool get isLoading => isUploading || isRegistering || isListing;
}

/// Content Notifier
///
/// Manages content upload, encryption, IPFS storage, and blockchain registration.
class ContentNotifier extends StateNotifier<ContentUploadState> {
  ContentNotifier(this.ref) : super(const ContentUploadState());

  final Ref ref;

  // Backend service URLs
  static const String ipfsServiceUrl = 'http://localhost:3000';
  static const String preProxyUrl = 'http://localhost:3001';

  /// Complete content upload workflow
  ///
  /// This is the main method that orchestrates the entire content upload process:
  /// 1. File encryption (AES-256)
  /// 2. IPFS upload
  /// 3. PRE setup (generate capsule, owner keys)
  /// 4. Blockchain registration (ContentRegistry.registerContentWithPRE)
  /// 5. Marketplace listing (Marketplace.createListing)
  ///
  /// Parameters:
  /// - filePath: Path to the file to upload
  /// - title: Content title
  /// - description: Content description
  /// - category: Content category (0-4)
  /// - price: Price in VLTC (will be converted to wei)
  /// - listingType: Listing type (0=full, 1=time, 2=usage)
  ///
  /// Returns: Content ID on success, null on failure
  Future<String?> uploadContent({
    required String filePath,
    required String title,
    required String description,
    required ContentCategory category,
    required int priceVltc,
    required ListingType listingType,
    int accessDuration = 0,
    int maxKeys = 0,
  }) async {
    try {
      // Initialize services
      final web3 = ref.read(web3ServiceProvider);
      final contracts = ref.read(contractServiceProvider);
      final transactionHistory = ref.read(transactionHistoryProvider.notifier);
      final wallet = ref.read(walletProvider);

      if (!wallet.isConnected) {
        state = state.copyWith(error: 'Wallet not connected');
        return null;
      }

      // ===== STEP 1: Encrypt File =====
      state = state.copyWith(
        currentStep: 'Encrypting file...',
        isUploading: true,
        error: null,
      );

      final file = File(filePath);
      final fileBytes = await file.readAsBytes();
      final fileSize = fileBytes.length;

      // Generate AES key
      final aesKey = EncryptionService.generateKey();

      // Encrypt content
      final encryptResult = EncryptionService.encrypt(
        Uint8List.fromList(fileBytes),
        aesKey,
      );
      final encryptedContent = encryptResult.ciphertext;

      // Calculate content hash (hash of encrypted content)
      final contentHashStr = EncryptionService.hashContent(encryptedContent);
      final contentHash = Uint8List.fromList(
        List<int>.generate(32, (i) => i < contentHashStr.length ~/ 2
          ? int.parse(contentHashStr.substring(i * 2, i * 2 + 2), radix: 16)
          : 0)
      );
      final contentHashHex = '0x${contentHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

      if (kDebugMode) {
        print('Content encrypted: ${encryptedContent.length} bytes');
        print('Content hash: $contentHashHex');
      }

      // ===== STEP 2: Upload to IPFS =====
      state = state.copyWith(
        currentStep: 'Uploading to IPFS...',
        uploadProgress: 0.25,
      );

      final ipfsHash = await _uploadToIPFS(encryptedContent, title);
      if (ipfsHash == null) {
        state = state.copyWith(
          error: 'Failed to upload to IPFS',
          isUploading: false,
        );
        return null;
      }

      state = state.copyWith(
        ipfsHash: ipfsHash,
        uploadProgress: 0.5,
      );

      if (kDebugMode) {
        print('Uploaded to IPFS: $ipfsHash');
      }

      // ===== STEP 3: Generate PRE Capsule =====
      state = state.copyWith(
        currentStep: 'Generating PRE capsule...',
        uploadProgress: 0.6,
      );

      // Generate owner's PRE keys
      final preKeys = await _generatePREKeys();
      if (preKeys == null) {
        state = state.copyWith(
          error: 'Failed to generate PRE keys',
          isUploading: false,
        );
        return null;
      }

      final ownerPublicKey = preKeys['publicKey'] as Uint8List;

      // Encrypt AES key with owner's public key (for now, just use the key directly)
      final encryptedAESKey = aesKey; // TODO: Implement PRE encryption

      // Generate PRE capsule
      final capsule = await _generateCapsule(aesKey, ownerPublicKey);
      if (capsule == null) {
        state = state.copyWith(
          error: 'Failed to generate PRE capsule',
          isUploading: false,
        );
        return null;
      }

      final capsuleHashStr = EncryptionService.hashContent(capsule);
      final capsuleHash = Uint8List.fromList(
        List<int>.generate(32, (i) => i < capsuleHashStr.length ~/ 2
          ? int.parse(capsuleHashStr.substring(i * 2, i * 2 + 2), radix: 16)
          : 0)
      );
      final capsuleHashHex = '0x${capsuleHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

      if (kDebugMode) {
        print('PRE capsule generated: $capsuleHashHex');
      }

      // ===== STEP 4: Create Metadata =====
      final metadata = {
        'title': title,
        'description': description,
        'ipfsHash': ipfsHash,
        'fileSize': fileSize,
        'mimeType': _getMimeType(filePath),
        'uploadedAt': DateTime.now().toIso8601String(),
      };

      final metadataJson = json.encode(metadata);
      final metadataBytes = Uint8List.fromList(utf8.encode(metadataJson));
      final metadataHashStr = EncryptionService.hashContent(metadataBytes);
      final metadataHash = Uint8List.fromList(
        List<int>.generate(32, (i) => i < metadataHashStr.length ~/ 2
          ? int.parse(metadataHashStr.substring(i * 2, i * 2 + 2), radix: 16)
          : 0)
      );
      final metadataHashHex = '0x${metadataHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

      // ===== STEP 5: Register on Blockchain =====
      state = state.copyWith(
        currentStep: 'Registering on blockchain...',
        uploadProgress: 0.7,
        isUploading: false,
        isRegistering: true,
      );

      // Convert hashes to bytes32 format for Solidity
      final contentHashBytes = _hexToBytes32(contentHashHex);
      final metadataHashBytes = _hexToBytes32(metadataHashHex);
      final capsuleHashBytes = _hexToBytes32(capsuleHashHex);

      // Call ContentRegistry.registerContentWithPRE
      final txHash = await web3.sendContract(
        contract: contracts.contentRegistry.contract,
        function: contracts.contentRegistry.registerContentWithPRE,
        parameters: [
          contentHashBytes,           // contentHash (bytes32)
          metadataHashBytes,          // metadataHash (bytes32)
          encryptedAESKey,            // encryptedKey (bytes)
          BigInt.from(fileSize),      // fileSize (uint256)
          BigInt.from(category.value), // contentType (uint8)
          BigInt.from(1),             // accessModel (1 = PRE)
          capsuleHashBytes,           // capsuleHash (bytes32)
          ownerPublicKey,             // ownerPublicKey (bytes)
        ],
      );

      if (kDebugMode) {
        print('Registration transaction: $txHash');
      }

      // Add to transaction history
      transactionHistory.addPendingTransaction(txHash, 'Register Content');

      state = state.copyWith(
        transactionHash: txHash,
        uploadProgress: 0.8,
      );

      // Wait for transaction confirmation
      state = state.copyWith(
        currentStep: 'Waiting for confirmation...',
      );

      final receipt = await web3.waitForReceipt(txHash);
      if (receipt == null || !receipt.status!) {
        state = state.copyWith(
          error: 'Transaction failed',
          isRegistering: false,
        );
        return null;
      }

      if (kDebugMode) {
        print('Transaction confirmed in block ${receipt.blockNumber}');
      }

      // Extract contentId from logs
      // The ContentRegistered event emits: (uint256 indexed contentId, address indexed owner, ...)
      // We need to parse the logs to get the contentId
      final contentIdBigInt = _extractContentIdFromReceipt(receipt);
      final contentId = contentIdBigInt.toString();

      state = state.copyWith(
        contentId: contentId,
        uploadProgress: 0.9,
        currentStep: 'Content registered successfully!',
      );

      if (kDebugMode) {
        print('Content registered with ID: $contentId');
      }

      // ===== STEP 6: Create Marketplace Listing (if price > 0) =====
      if (priceVltc > 0) {
        state = state.copyWith(
          currentStep: 'Creating marketplace listing...',
          isRegistering: false,
          isListing: true,
        );

        final priceWei = VaultTokenContract.vltcToWei(priceVltc);

        final listingTxHash = await web3.sendContract(
          contract: contracts.marketplace.contract,
          function: contracts.marketplace.createListing,
          parameters: [
            contentIdBigInt,              // contentId (uint256)
            priceWei,                     // price (uint256)
            BigInt.from(listingType.value), // listingType (uint8)
            BigInt.from(accessDuration),  // accessDuration (uint256)
            BigInt.from(maxKeys),         // maxKeys (uint256)
          ],
        );

        if (kDebugMode) {
          print('Listing transaction: $listingTxHash');
        }

        // Add to transaction history
        transactionHistory.addPendingTransaction(listingTxHash, 'Create Listing');

        // Wait for confirmation
        final listingReceipt = await web3.waitForReceipt(listingTxHash);
        if (listingReceipt == null || !listingReceipt.status!) {
          state = state.copyWith(
            error: 'Listing transaction failed',
            isListing: false,
          );
          return null;
        }

        // Extract listingId from logs
        final listingIdBigInt = _extractListingIdFromReceipt(listingReceipt);
        final listingId = listingIdBigInt.toString();

        state = state.copyWith(
          listingId: listingId,
          uploadProgress: 1.0,
          currentStep: 'Content listed successfully!',
          isListing: false,
        );

        if (kDebugMode) {
          print('Listing created with ID: $listingId');
        }
      } else {
        state = state.copyWith(
          uploadProgress: 1.0,
          isRegistering: false,
        );
      }

      // Refresh wallet balances
      await ref.read(walletProvider.notifier).refreshBalances();

      return contentId;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Upload error: $e');
        print(stackTrace);
      }

      state = state.copyWith(
        error: e.toString(),
        isUploading: false,
        isRegistering: false,
        isListing: false,
      );

      return null;
    }
  }

  /// Upload encrypted content to IPFS
  ///
  /// Uses the IPFS Gateway service (localhost:3000)
  Future<String?> _uploadToIPFS(Uint8List encryptedContent, String filename) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$ipfsServiceUrl/api/ipfs/upload'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          encryptedContent,
          filename: filename,
        ),
      );

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseBody);
        return jsonResponse['ipfsHash'] as String;
      } else {
        if (kDebugMode) {
          print('IPFS upload failed: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('IPFS upload error: $e');
      }
      return null;
    }
  }

  /// Generate PRE keys for the owner
  ///
  /// Uses the PRE Proxy service (localhost:3001)
  Future<Map<String, Uint8List>?> _generatePREKeys() async {
    try {
      final response = await http.post(
        Uri.parse('$preProxyUrl/api/proxy/generate-keys'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // Parse hex strings to bytes
        final publicKey = _hexStringToBytes(jsonResponse['publicKey']);
        final privateKey = _hexStringToBytes(jsonResponse['privateKey']);

        return {
          'publicKey': publicKey,
          'privateKey': privateKey,
        };
      } else {
        if (kDebugMode) {
          print('PRE key generation failed: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('PRE key generation error: $e');
      }
      return null;
    }
  }

  /// Generate PRE capsule
  ///
  /// Uses the PRE Proxy service (localhost:3001)
  Future<Uint8List?> _generateCapsule(Uint8List aesKey, Uint8List ownerPublicKey) async {
    try {
      final response = await http.post(
        Uri.parse('$preProxyUrl/api/proxy/generate-capsule'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'aesKey': _bytesToHexString(aesKey),
          'publicKey': _bytesToHexString(ownerPublicKey),
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return _hexStringToBytes(jsonResponse['capsule']);
      } else {
        if (kDebugMode) {
          print('Capsule generation failed: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Capsule generation error: $e');
      }
      return null;
    }
  }

  /// Extract contentId from transaction receipt
  ///
  /// Parses the ContentRegistered event logs to extract the content ID.
  /// Event signature: ContentRegistered(uint256 indexed contentId, address indexed owner, ...)
  BigInt _extractContentIdFromReceipt(TransactionReceipt receipt) {
    // The first topic is the event signature hash
    // The second topic is the indexed contentId
    if (receipt.logs.isNotEmpty) {
      final log = receipt.logs.first;
      if (log.topics != null && log.topics!.length > 1) {
        // contentId is the second topic (index 1)
        final contentIdHex = log.topics![1] ?? '';
        if (contentIdHex.isNotEmpty && contentIdHex.length > 2) {
          return BigInt.parse(contentIdHex.substring(2), radix: 16);
        }
      }
    }

    // Fallback: return 0 if we can't parse (should not happen)
    return BigInt.zero;
  }

  /// Extract listingId from transaction receipt
  ///
  /// Parses the ListingCreated event logs to extract the listing ID.
  /// Event signature: ListingCreated(uint256 indexed listingId, address indexed seller, ...)
  BigInt _extractListingIdFromReceipt(TransactionReceipt receipt) {
    if (receipt.logs.isNotEmpty) {
      final log = receipt.logs.first;
      if (log.topics != null && log.topics!.length > 1) {
        // listingId is the second topic (index 1)
        final listingIdHex = log.topics![1] ?? '';
        if (listingIdHex.isNotEmpty && listingIdHex.length > 2) {
          return BigInt.parse(listingIdHex.substring(2), radix: 16);
        }
      }
    }

    return BigInt.zero;
  }

  /// Convert hex string to bytes32 format (32 bytes)
  Uint8List _hexToBytes32(String hex) {
    final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;
    final bytes = _hexStringToBytes('0x${cleanHex.padLeft(64, '0')}');
    return bytes;
  }

  /// Convert hex string to bytes
  Uint8List _hexStringToBytes(String hex) {
    final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;
    final bytes = Uint8List(cleanHex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  /// Convert bytes to hex string
  String _bytesToHexString(Uint8List bytes) {
    return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Get MIME type from file path
  String _getMimeType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }

  /// Reset state
  void reset() {
    state = const ContentUploadState();
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Content upload provider
final contentUploadProvider = StateNotifierProvider<ContentNotifier, ContentUploadState>((ref) {
  return ContentNotifier(ref);
});

// web3ServiceProvider is now imported from wallet_provider.dart

/// Encryption service provider (singleton)
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

// Contract service provider is now imported from wallet_provider.dart

// ============================================================================
// CONTENT BROWSE PROVIDERS
// ============================================================================

/// Provider for ContentBrowseService
final contentBrowseServiceProvider = Provider<ContentBrowseService>((ref) {
  final web3Service = ref.watch(web3ServiceProvider);
  final contractService = ref.watch(contractServiceProvider);

  return ContentBrowseService(
    web3Service: web3Service,
    contractService: contractService,
  );
});

/// Content browse state
class ContentBrowseState {
  final List<ContentItem> items;
  final bool isLoading;
  final String? error;
  final ContentCategory? selectedCategory;
  final String searchQuery;
  final bool showFreeOnly;
  final bool showPaidOnly;

  const ContentBrowseState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategory,
    this.searchQuery = '',
    this.showFreeOnly = false,
    this.showPaidOnly = false,
  });

  ContentBrowseState copyWith({
    List<ContentItem>? items,
    bool? isLoading,
    String? error,
    ContentCategory? selectedCategory,
    bool clearCategory = false,
    String? searchQuery,
    bool? showFreeOnly,
    bool? showPaidOnly,
  }) {
    return ContentBrowseState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      searchQuery: searchQuery ?? this.searchQuery,
      showFreeOnly: showFreeOnly ?? this.showFreeOnly,
      showPaidOnly: showPaidOnly ?? this.showPaidOnly,
    );
  }

  /// Get filtered items based on current filters
  List<ContentItem> get filteredItems {
    var result = items;

    // Filter by category
    if (selectedCategory != null) {
      result = result.where((item) => item.category == selectedCategory).toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result.where((item) {
        final title = item.title?.toLowerCase() ?? '';
        final description = item.description?.toLowerCase() ?? '';
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    // Filter by price
    if (showFreeOnly) {
      result = result.where((item) => item.isFree).toList();
    } else if (showPaidOnly) {
      result = result.where((item) => !item.isFree).toList();
    }

    return result;
  }
}

/// Content browse notifier
class ContentBrowseNotifier extends StateNotifier<ContentBrowseState> {
  final ContentBrowseService browseService;

  ContentBrowseNotifier(this.browseService) : super(const ContentBrowseState());

  /// Load all content
  Future<void> loadContent({bool refresh = false}) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      final items = await browseService.getAllContent(
        limit: 100,
        includeInactive: false,
      );

      state = state.copyWith(
        items: items,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load content by owner
  Future<void> loadContentByOwner(String ownerAddress) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      final items = await browseService.getContentByOwner(ownerAddress);

      state = state.copyWith(
        items: items,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Set category filter
  void setCategory(ContentCategory? category) {
    state = state.copyWith(
      selectedCategory: category,
      clearCategory: category == null,
    );
  }

  /// Set search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Toggle free content filter
  void toggleFreeOnly() {
    state = state.copyWith(
      showFreeOnly: !state.showFreeOnly,
      showPaidOnly: false, // Can't have both
    );
  }

  /// Toggle paid content filter
  void togglePaidOnly() {
    state = state.copyWith(
      showPaidOnly: !state.showPaidOnly,
      showFreeOnly: false, // Can't have both
    );
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(
      selectedCategory: null,
      clearCategory: true,
      searchQuery: '',
      showFreeOnly: false,
      showPaidOnly: false,
    );
  }

  /// Refresh content
  Future<void> refresh() async {
    await loadContent(refresh: true);
  }
}

/// Provider for content browse state
final contentBrowseProvider =
    StateNotifierProvider<ContentBrowseNotifier, ContentBrowseState>((ref) {
  final browseService = ref.watch(contentBrowseServiceProvider);
  return ContentBrowseNotifier(browseService);
});

/// Provider for filtered content items
final filteredContentProvider = Provider<List<ContentItem>>((ref) {
  final state = ref.watch(contentBrowseProvider);
  return state.filteredItems;
});

/// Provider for content categories with counts
final categoriesWithCountsProvider = Provider<Map<ContentCategory, int>>((ref) {
  final state = ref.watch(contentBrowseProvider);

  final counts = <ContentCategory, int>{};

  for (final category in ContentCategory.values) {
    counts[category] = state.items
        .where((item) => item.category == category)
        .length;
  }

  return counts;
});

/// Provider for a single content item
final contentItemProvider = FutureProvider.family<ContentItem?, BigInt>((ref, contentId) async {
  final browseService = ref.watch(contentBrowseServiceProvider);
  return await browseService.getContent(contentId);
});

/// Provider for user's created content (by creator address)
/// Uses getCreatorContents to get content originally created by the user
final userCreatedContentProvider = FutureProvider.family<List<ContentItem>, String>((ref, creatorAddress) async {
  final browseService = ref.watch(contentBrowseServiceProvider);
  return await browseService.getContentByCreator(creatorAddress);
});

/// Provider for user's purchased content (from blockchain events)
final userPurchasedContentProvider = FutureProvider.family<List<ContentItem>, String>((ref, buyerAddress) async {
  final browseService = ref.watch(contentBrowseServiceProvider);
  return await browseService.getPurchasedContent(buyerAddress);
});
