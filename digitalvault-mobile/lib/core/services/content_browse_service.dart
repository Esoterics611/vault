import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import '../contracts/content_registry_contract.dart';
import '../services/web3_service.dart';
import '../services/contract_service.dart';

/// Content Item Model
///
/// Represents a piece of content in the DigitalVault marketplace.
class ContentItem {
  final BigInt id;
  final String owner;
  final String contentHash;
  final String metadataHash;
  final BigInt fileSize;
  final DateTime timestamp;
  final ContentCategory category;
  final AccessModel accessModel;
  final bool isActive;

  // Additional metadata (fetched from IPFS)
  final String? title;
  final String? description;
  final String? ipfsCid;
  final BigInt? priceInVLTC;
  final String? thumbnailUrl;

  ContentItem({
    required this.id,
    required this.owner,
    required this.contentHash,
    required this.metadataHash,
    required this.fileSize,
    required this.timestamp,
    required this.category,
    required this.accessModel,
    required this.isActive,
    this.title,
    this.description,
    this.ipfsCid,
    this.priceInVLTC,
    this.thumbnailUrl,
  });

  /// Create from blockchain data
  factory ContentItem.fromBlockchain(
    BigInt id,
    List<dynamic> blockchainData, {
    Map<String, dynamic>? metadata,
  }) {
    return ContentItem(
      id: id,
      owner: blockchainData[0].toString(),
      contentHash: '0x${blockchainData[1].toString()}',
      metadataHash: '0x${blockchainData[2].toString()}',
      fileSize: blockchainData[4] as BigInt,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (blockchainData[5] as BigInt).toInt() * 1000,
      ),
      category: ContentCategory.values[(blockchainData[6] as BigInt).toInt()],
      accessModel: AccessModel.values[(blockchainData[7] as BigInt).toInt()],
      isActive: blockchainData[8] as bool,
      title: metadata?['title'],
      description: metadata?['description'],
      ipfsCid: metadata?['ipfsCid'],
      priceInVLTC: metadata?['priceInVLTC'] != null
          ? BigInt.parse(metadata!['priceInVLTC'].toString())
          : null,
      thumbnailUrl: metadata?['thumbnailUrl'],
    );
  }

  /// Create ContentItem from getContentInfo struct
  ///
  /// The Content struct from getContentInfo has these fields:
  /// [0] contentHash, [1] metadataHash, [2] owner, [3] contentType, [4] accessModel,
  /// [5] isActive, [6] capsuleVersion, [7] usesPRE, [8] creator, [9] createdAt,
  /// [10] fileSize, [11] encryptedKey, [12] viewCount, [13] capsuleHash
  factory ContentItem.fromContentInfo(
    BigInt id,
    dynamic contentData, {
    Map<String, dynamic>? metadata,
  }) {
    // Debug: print content data structure
    print('Content data type: ${contentData.runtimeType}');
    print('Content data length: ${contentData is List ? contentData.length : "not a list"}');

    // Handle both list and tuple formats from web3dart
    final data = contentData is List ? contentData : [contentData];

    // Safely extract data with defaults
    final owner = data.length > 2 ? data[2].toString() : '0x0';
    final contentHash = data.length > 0 ? '0x${data[0].toString()}' : '0x0';
    final metadataHash = data.length > 1 ? '0x${data[1].toString()}' : '0x0';
    final fileSize = data.length > 10 ? (data[10] as BigInt) : BigInt.zero;
    final createdAt = data.length > 9 ? (data[9] as BigInt).toInt() : 0;
    final contentType = data.length > 3 ? (data[3] as BigInt).toInt().clamp(0, ContentCategory.values.length - 1) : 0;
    final accessModel = data.length > 4 ? (data[4] as BigInt).toInt().clamp(0, AccessModel.values.length - 1) : 0;
    final isActive = data.length > 5 ? (data[5] as bool) : true;

    return ContentItem(
      id: id,
      owner: owner,
      contentHash: contentHash,
      metadataHash: metadataHash,
      fileSize: fileSize,
      timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      category: ContentCategory.values[contentType],
      accessModel: AccessModel.values[accessModel],
      isActive: isActive,
      title: metadata?['title'],
      description: metadata?['description'],
      ipfsCid: metadata?['ipfsCid'],
      priceInVLTC: metadata?['priceInVLTC'] != null
          ? BigInt.parse(metadata!['priceInVLTC'].toString())
          : null,
      thumbnailUrl: metadata?['thumbnailUrl'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'id': id.toString(),
    'owner': owner,
    'contentHash': contentHash,
    'metadataHash': metadataHash,
    'fileSize': fileSize.toString(),
    'timestamp': timestamp.toIso8601String(),
    'category': category.name,
    'accessModel': accessModel.name,
    'isActive': isActive,
    'title': title,
    'description': description,
    'ipfsCid': ipfsCid,
    'priceInVLTC': priceInVLTC?.toString(),
    'thumbnailUrl': thumbnailUrl,
  };

  /// Get formatted file size
  String get formattedFileSize {
    final bytes = fileSize.toDouble();
    if (bytes < 1024) return '${bytes.toInt()} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get formatted price
  String get formattedPrice {
    if (priceInVLTC == null || priceInVLTC == BigInt.zero) {
      return 'Free';
    }
    // Convert from wei to VLTC (18 decimals)
    final vltc = priceInVLTC! ~/ BigInt.from(10).pow(18);
    return '$vltc VLTC';
  }

  /// Check if content is free
  bool get isFree => priceInVLTC == null || priceInVLTC == BigInt.zero;
}

/// Content Browse Service
///
/// Service for fetching and browsing content from the blockchain
/// and IPFS metadata.
class ContentBrowseService {
  final Web3Service web3Service;
  final ContractService contractService;
  final String ipfsGatewayUrl;

  ContentBrowseService({
    required this.web3Service,
    required this.contractService,
    this.ipfsGatewayUrl = 'http://10.0.2.2:3000', // Android emulator host IP
  });

  /// Ensure contracts are initialized before any read operation.
  /// Auto-initializes in read-only mode on Base Sepolia if not yet ready.
  Future<void> _ensureInitialized() async {
    web3Service.ensureReadOnly(chainId: 84532);
    if (!contractService.isInitialized) {
      await contractService.initReadOnly(chainId: 84532);
    }
  }

  /// Get all registered content
  ///
  /// Fetches content from the blockchain and enriches with IPFS metadata.
  /// Since there's no public content counter, we iterate through IDs
  /// starting from 1 until we hit consecutive errors.
  ///
  /// Parameters:
  /// - limit: Maximum number of items to fetch (default: 100)
  /// - offset: Number of items to skip (default: 0)
  /// - includeInactive: Include deactivated content (default: false)
  ///
  /// Returns list of ContentItem objects.
  Future<List<ContentItem>> getAllContent({
    int limit = 100,
    int offset = 0,
    bool includeInactive = false,
  }) async {
    try {
      await _ensureInitialized();
      final items = <ContentItem>[];
      int consecutiveErrors = 0;
      const maxConsecutiveErrors = 3; // Stop after 3 consecutive errors
      final startId = offset + 1; // Content IDs start at 1

      // Fetch content items starting from startId
      for (int i = startId; items.length < limit && consecutiveErrors < maxConsecutiveErrors; i++) {
        try {
          final contentId = BigInt.from(i);

          // Get blockchain data using getContentInfo
          final result = await web3Service.call(
            contract: contractService.contentRegistry.contract,
            function: contractService.contentRegistry.getContentInfo,
            params: [contentId],
          );

          // Reset error counter on success
          consecutiveErrors = 0;

          // Parse the Content struct returned by getContentInfo
          // The struct has: contentHash, metadataHash, owner, contentType, accessModel,
          // isActive, capsuleVersion, usesPRE, creator, createdAt, fileSize, encryptedKey, viewCount, capsuleHash
          final contentData = result[0];

          // Check if active (index 5 in struct)
          final isActive = contentData[5] as bool;
          if (!includeInactive && !isActive) {
            continue;
          }

          // Try to fetch metadata from IPFS
          Map<String, dynamic>? metadata;
          try {
            final metadataHash = contentData[1].toString();
            metadata = await _fetchMetadataFromIPFS(metadataHash);
          } catch (e) {
            print('Failed to fetch metadata for content $i: $e');
          }

          items.add(ContentItem.fromContentInfo(
            contentId,
            contentData,
            metadata: metadata,
          ));
        } catch (e) {
          consecutiveErrors++;
          print('Error fetching content $i: $e (consecutive: $consecutiveErrors)');
        }
      }

      return items;
    } catch (e) {
      throw Exception('Failed to fetch content: $e');
    }
  }

  /// Get content by owner
  ///
  /// Fetches all content owned by a specific address.
  Future<List<ContentItem>> getContentByOwner(String ownerAddress) async {
    try {
      await _ensureInitialized();
      // Get content IDs owned by address
      final result = await web3Service.call(
        contract: contractService.contentRegistry.contract,
        function: contractService.contentRegistry.getOwnerContents,
        params: [EthereumAddress.fromHex(ownerAddress)],
      );

      final contentIds = result[0] as List<dynamic>;

      if (contentIds.isEmpty) {
        return [];
      }

      final items = <ContentItem>[];

      // Fetch details for each content ID
      for (final id in contentIds) {
        try {
          final contentId = id as BigInt;

          final contentResult = await web3Service.call(
            contract: contractService.contentRegistry.contract,
            function: contractService.contentRegistry.getContent,
            params: [contentId],
          );

          // Try to fetch metadata
          Map<String, dynamic>? metadata;
          try {
            final metadataHash = contentResult[2].toString();
            metadata = await _fetchMetadataFromIPFS(metadataHash);
          } catch (e) {
            print('Failed to fetch metadata for content $contentId: $e');
          }

          items.add(ContentItem.fromBlockchain(
            contentId,
            contentResult,
            metadata: metadata,
          ));
        } catch (e) {
          print('Error fetching content $id: $e');
        }
      }

      return items;
    } catch (e) {
      throw Exception('Failed to fetch content by owner: $e');
    }
  }

  /// Get content created by user
  ///
  /// Fetches all content originally created by a specific address.
  /// This is different from getContentByOwner which returns current ownership.
  Future<List<ContentItem>> getContentByCreator(String creatorAddress) async {
    try {
      await _ensureInitialized();
      print('Fetching content created by: $creatorAddress');

      // Get content IDs created by address
      final result = await web3Service.call(
        contract: contractService.contentRegistry.contract,
        function: contractService.contentRegistry.getCreatorContents,
        params: [EthereumAddress.fromHex(creatorAddress)],
      );

      final contentIds = result[0] as List<dynamic>;
      print('Found ${contentIds.length} content items created by user');

      if (contentIds.isEmpty) {
        return [];
      }

      final items = <ContentItem>[];

      // Fetch details for each content ID
      for (final id in contentIds) {
        try {
          final contentId = id as BigInt;

          // Use getContentInfo instead of getContent for the new struct format
          final contentResult = await web3Service.call(
            contract: contractService.contentRegistry.contract,
            function: contractService.contentRegistry.getContentInfo,
            params: [contentId],
          );

          // Try to fetch metadata
          Map<String, dynamic>? metadata;
          try {
            // contentResult[0] is the Content struct, metadataHash is at index 1
            final contentData = contentResult[0];
            final metadataHash = contentData[1].toString();
            metadata = await _fetchMetadataFromIPFS(metadataHash);
          } catch (e) {
            print('Failed to fetch metadata for content $contentId: $e');
          }

          items.add(ContentItem.fromContentInfo(
            contentId,
            contentResult[0],
            metadata: metadata,
          ));
        } catch (e) {
          print('Error fetching content $id: $e');
        }
      }

      return items;
    } catch (e) {
      print('Error in getContentByCreator: $e');
      throw Exception('Failed to fetch content by creator: $e');
    }
  }

  /// Get single content item
  ///
  /// Fetches details for a specific content ID.
  Future<ContentItem?> getContent(BigInt contentId) async {
    try {
      await _ensureInitialized();
      final result = await web3Service.call(
        contract: contractService.contentRegistry.contract,
        function: contractService.contentRegistry.getContent,
        params: [contentId],
      );

      // Try to fetch metadata
      Map<String, dynamic>? metadata;
      try {
        final metadataHash = result[2].toString();
        metadata = await _fetchMetadataFromIPFS(metadataHash);
      } catch (e) {
        print('Failed to fetch metadata: $e');
      }

      return ContentItem.fromBlockchain(
        contentId,
        result,
        metadata: metadata,
      );
    } catch (e) {
      print('Error fetching content $contentId: $e');
      return null;
    }
  }

  /// Search content by category
  ///
  /// Filters content by category type.
  Future<List<ContentItem>> getContentByCategory(
    ContentCategory category, {
    int limit = 100,
  }) async {
    final allContent = await getAllContent(limit: limit);
    return allContent
        .where((item) => item.category == category)
        .toList();
  }

  /// Search content by title/description
  ///
  /// Performs client-side search on fetched content.
  /// For production, this should be done server-side with indexing.
  Future<List<ContentItem>> searchContent(
    String query, {
    int limit = 100,
  }) async {
    if (query.trim().isEmpty) {
      return await getAllContent(limit: limit);
    }

    final allContent = await getAllContent(limit: limit);
    final lowerQuery = query.toLowerCase();

    return allContent.where((item) {
      final title = item.title?.toLowerCase() ?? '';
      final description = item.description?.toLowerCase() ?? '';
      return title.contains(lowerQuery) || description.contains(lowerQuery);
    }).toList();
  }

  /// Get free content only
  Future<List<ContentItem>> getFreeContent({int limit = 100}) async {
    final allContent = await getAllContent(limit: limit);
    return allContent.where((item) => item.isFree).toList();
  }

  /// Get paid content only
  Future<List<ContentItem>> getPaidContent({int limit = 100}) async {
    final allContent = await getAllContent(limit: limit);
    return allContent.where((item) => !item.isFree).toList();
  }

  /// Fetch metadata from IPFS gateway
  ///
  /// Tries the local IPFS gateway first, then falls back to Pinata public gateway.
  Future<Map<String, dynamic>> _fetchMetadataFromIPFS(String metadataHash) async {
    if (metadataHash.isEmpty || metadataHash == '0x0') return {};

    // Clean the hash — remove 0x prefix if present
    final cleanHash = metadataHash.startsWith('0x')
        ? metadataHash.substring(2)
        : metadataHash;

    // Skip zero hashes
    if (cleanHash == '0' * 64 || cleanHash.replaceAll('0', '').isEmpty) return {};

    // Try local IPFS gateway first
    final urls = [
      '$ipfsGatewayUrl/api/ipfs/metadata/$cleanHash',
      'https://gateway.pinata.cloud/ipfs/$cleanHash',
      'https://ipfs.io/ipfs/$cleanHash',
    ];

    for (final url in urls) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final body = response.body.trim();
          if (body.startsWith('{')) {
            return json.decode(body) as Map<String, dynamic>;
          }
        }
      } catch (_) {
        // Try next URL
      }
    }

    return {};
  }

  /// Get IPFS gateway URL for content
  ///
  /// Returns the full URL to access encrypted content from IPFS.
  String getContentUrl(String ipfsCid) {
    return '$ipfsGatewayUrl/api/ipfs/content/$ipfsCid';
  }

  /// Get thumbnail URL
  ///
  /// Returns URL for content thumbnail (if available).
  String? getThumbnailUrl(ContentItem item) {
    if (item.thumbnailUrl != null) {
      return '$ipfsGatewayUrl${item.thumbnailUrl}';
    }
    return null;
  }

  /// Get content purchased by user from blockchain events
  ///
  /// Queries the Marketplace contract for ListingPurchased events
  /// where the buyer is the specified address.
  ///
  /// This replaces the local Hive storage with real blockchain data.
  Future<List<ContentItem>> getPurchasedContent(String buyerAddress) async {
    try {
      await _ensureInitialized();
      print('Fetching purchased content for address: $buyerAddress');

      // Get marketplace contract
      final marketplaceContract = contractService.marketplace.contract;

      // Get ListingPurchased events filtered by buyer
      // Note: web3dart doesn't have great event filtering, so we'll:
      // 1. Get recent blocks
      // 2. Query events
      // 3. Filter by buyer address

      // For now, we'll use a simpler approach: query all listings
      // and check ContentRegistry for ownership transfers to this address

      // Alternative: Query ContentOwnershipTransferred events from ContentRegistry
      // This is more reliable as it shows all content owned by the user

      final purchasedContentIds = <BigInt>{};

      // Get all content owned by the user from ContentRegistry
      final ownedResult = await web3Service.call(
        contract: contractService.contentRegistry.contract,
        function: contractService.contentRegistry.getOwnerContents,
        params: [EthereumAddress.fromHex(buyerAddress)],
      );

      final ownedContentIds = (ownedResult[0] as List<dynamic>).cast<BigInt>();

      print('User owns ${ownedContentIds.length} content items');

      if (ownedContentIds.isEmpty) {
        return [];
      }

      // Now we need to filter out content that the user created (not purchased)
      // For this MVP, we'll return all owned content as "purchased"
      // In production, we'd check ContentOwnershipTransferred events to see
      // if the content was originally created by this user or purchased

      final items = <ContentItem>[];

      for (final contentId in ownedContentIds) {
        try {
          final contentResult = await web3Service.call(
            contract: contractService.contentRegistry.contract,
            function: contractService.contentRegistry.getContent,
            params: [contentId],
          );

          // Check if this content was originally created by the user
          final owner = contentResult[0] as dynamic;
          final ownerAddress = owner.toString().toLowerCase();
          final userAddressLower = buyerAddress.toLowerCase();

          // For now, include all owned content
          // TODO: Filter by checking if user is original creator vs purchased
          // This would require querying ContentRegistered events

          // Try to fetch metadata
          Map<String, dynamic>? metadata;
          try {
            final metadataHash = contentResult[2].toString();
            metadata = await _fetchMetadataFromIPFS(metadataHash);
          } catch (e) {
            print('Failed to fetch metadata for content $contentId: $e');
          }

          items.add(ContentItem.fromBlockchain(
            contentId,
            contentResult,
            metadata: metadata,
          ));
        } catch (e) {
          print('Error fetching purchased content $contentId: $e');
        }
      }

      print('Fetched ${items.length} purchased content items');
      return items;
    } catch (e) {
      print('Error fetching purchased content: $e');
      throw Exception('Failed to fetch purchased content: $e');
    }
  }
}
