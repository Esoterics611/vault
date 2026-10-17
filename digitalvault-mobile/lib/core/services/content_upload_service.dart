import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:web3dart/web3dart.dart';
import '../constants/api_endpoints.dart';
import '../constants/contract_addresses.dart';
import 'symmetric_crypto_service.dart';
import 'web3_service.dart';

/// Upload progress steps
enum UploadStep {
  selecting(0, 'Selecting file'),
  encrypting(1, 'Encrypting content'),
  creatingCapsule(2, 'Creating PRE capsule'),
  uploadingToIPFS(3, 'Uploading to IPFS'),
  storingCapsule(4, 'Storing capsule'),
  registering(5, 'Registering on blockchain'),
  complete(6, 'Complete');

  const UploadStep(this.value, this.description);
  final int value;
  final String description;

  double get progress => (value / 6.0);
  bool get isComplete => this == UploadStep.complete;
}

/// Content metadata
class ContentMetadata {
  final String title;
  final String description;
  final String contentType; // image, video, document, etc.
  final int fileSize;
  final String? previewUrl;
  final Map<String, dynamic>? additionalData;

  ContentMetadata({
    required this.title,
    required this.description,
    required this.contentType,
    required this.fileSize,
    this.previewUrl,
    this.additionalData,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'contentType': contentType,
        'fileSize': fileSize,
        'previewUrl': previewUrl,
        'additionalData': additionalData,
        'uploadedAt': DateTime.now().toIso8601String(),
      };
}

/// Upload result
class UploadResult {
  final String contentId; // Token ID from contract
  final String ipfsCid;
  final String capsuleId;
  final String txHash;
  final ContentMetadata metadata;
  final String encryptionKeyHex; // For owner's records

  UploadResult({
    required this.contentId,
    required this.ipfsCid,
    required this.capsuleId,
    required this.txHash,
    required this.metadata,
    required this.encryptionKeyHex,
  });

  Map<String, dynamic> toJson() => {
        'contentId': contentId,
        'ipfsCid': ipfsCid,
        'capsuleId': capsuleId,
        'txHash': txHash,
        'metadata': metadata.toJson(),
        'encryptionKeyHex': encryptionKeyHex,
      };
}

/// PRE Capsule data
class PreCapsule {
  final String capsuleId;
  final String encryptedKeyHex;
  final EthereumAddress owner;
  final DateTime createdAt;

  PreCapsule({
    required this.capsuleId,
    required this.encryptedKeyHex,
    required this.owner,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'capsuleId': capsuleId,
        'encryptedKey': encryptedKeyHex,
        'owner': owner.hex,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Content Upload Service
///
/// Handles the complete upload flow:
/// 1. Encrypt content with AES-256-GCM
/// 2. Create PRE capsule for the AES key
/// 3. Upload encrypted content to IPFS
/// 4. Store capsule in PRE Proxy
/// 5. Register content on blockchain
class ContentUploadService {
  final Web3Service _web3Service;
  final Dio _dio = Dio();

  ContentUploadService(this._web3Service);

  /// Complete upload flow
  ///
  /// Parameters:
  /// - file: The file to upload
  /// - metadata: Content metadata
  /// - priceInVLTC: Price in VLTC tokens (0 for free)
  /// - onProgress: Callback for progress updates
  ///
  /// Returns: UploadResult with all upload details
  Future<UploadResult> uploadContent({
    required File file,
    required ContentMetadata metadata,
    required BigInt priceInVLTC,
    Function(UploadStep step, double progress)? onProgress,
  }) async {
    try {
      // Check if Web3Service is initialized
      if (!_web3Service.isInitialized) {
        throw Exception('Wallet not connected. Please connect your wallet first.');
      }

      // Step 1: Read file
      onProgress?.call(UploadStep.encrypting, 0.0);
      final fileBytes = await file.readAsBytes();

      // Step 2: Encrypt content with AES-256-GCM
      onProgress?.call(UploadStep.encrypting, 0.3);
      final encryptionResult = await SymmetricCryptoService.encrypt(
        data: fileBytes,
      );

      // Combine encrypted data (nonce + ciphertext + mac)
      final encryptedBytes = encryptionResult.toBytes();

      // Step 3: Create PRE capsule for AES key
      onProgress?.call(UploadStep.creatingCapsule, 0.5);
      final capsule = await _createPreCapsule(
        aesKey: encryptionResult.key,
        owner: _web3Service.userAddress!,
      );

      // Step 4: Upload encrypted content to IPFS
      onProgress?.call(UploadStep.uploadingToIPFS, 0.6);
      final ipfsCid = await _uploadToIPFS(
        data: encryptedBytes,
        metadata: metadata,
      );

      // Step 5: Register content on blockchain FIRST (to get contentId)
      onProgress?.call(UploadStep.registering, 0.75);
      final result = await _registerOnChain(
        ipfsCid: ipfsCid,
        capsuleId: capsule.capsuleId,
        price: priceInVLTC,
        metadata: metadata,
        fileSize: fileBytes.length,  // Pass actual file size
        encryptedKey: encryptionResult.key,  // Pass encrypted AES key
      );

      // Step 6: Store capsule in PRE Proxy (now that we have contentId)
      onProgress?.call(UploadStep.storingCapsule, 0.85);
      await _storeCapsule(
        capsule: capsule,
        contentId: result['contentId'] as int,
      );

      // Complete
      onProgress?.call(UploadStep.complete, 1.0);

      return UploadResult(
        contentId: result['contentId'].toString(), // Convert int to String
        ipfsCid: ipfsCid,
        capsuleId: capsule.capsuleId,
        txHash: result['txHash'],
        metadata: metadata,
        encryptionKeyHex: SymmetricCryptoService.toHex(encryptionResult.key),
      );
    } catch (e) {
      print('Upload failed: $e');
      rethrow;
    }
  }

  /// Create PRE capsule for AES key
  ///
  /// In production, this would use NuCypher/Threshold PRE library.
  /// For MVP, we'll simulate with the owner's public key encryption.
  Future<PreCapsule> _createPreCapsule({
    required Uint8List aesKey,
    required EthereumAddress owner,
  }) async {
    try {
      // For MVP: Store the AES key in a capsule structure
      // In production, this would:
      // 1. Use PRE to encrypt the AES key with policy public key
      // 2. Create delegatable capsule
      // 3. Allow re-encryption for buyers

      // Generate capsule ID (hash of key + owner + timestamp)
      final capsuleData = BytesBuilder();
      capsuleData.add(aesKey);
      capsuleData.add(utf8.encode(owner.hex));
      capsuleData.add(utf8.encode(DateTime.now().toIso8601String()));

      final capsuleIdBytes = SymmetricCryptoService.hash(capsuleData.toBytes());
      final capsuleId = '0x${SymmetricCryptoService.toHex(capsuleIdBytes)}';

      // For MVP: Use simple hex encoding
      // In production: Use PRE encryption
      final encryptedKeyHex = SymmetricCryptoService.toHex(aesKey);

      return PreCapsule(
        capsuleId: capsuleId,
        encryptedKeyHex: encryptedKeyHex,
        owner: owner,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to create PRE capsule: $e');
    }
  }

  /// Upload encrypted content to IPFS
  Future<String> _uploadToIPFS({
    required Uint8List data,
    required ContentMetadata metadata,
  }) async {
    try {
      // Create multipart form data
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          data,
          filename: 'encrypted_${DateTime.now().millisecondsSinceEpoch}',
        ),
        'metadata': jsonEncode(metadata.toJson()),
      });

      // Upload to IPFS gateway
      final response = await _dio.post(
        '${ApiEndpoints.ipfsGatewayUrl}${ApiEndpoints.ipfsUpload}',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final cid = response.data['cid'] ?? response.data['IpfsHash'];
        if (cid == null) {
          throw Exception('No CID returned from IPFS');
        }
        return cid;
      }

      throw Exception('IPFS upload failed: ${response.statusCode}');
    } catch (e) {
      throw Exception('IPFS upload error: $e');
    }
  }

  /// Store capsule in PRE Proxy
  /// Must be called AFTER blockchain registration to get contentId
  Future<void> _storeCapsule({
    required PreCapsule capsule,
    required int contentId,
  }) async {
    try {
      // Backend expects: contentId, capsuleData, capsuleHash
      final payload = {
        'contentId': contentId,
        'capsuleData': capsule.encryptedKeyHex, // The encrypted AES key
        'capsuleHash': capsule.capsuleId,       // Hash of the capsule
      };

      final response = await _dio.post(
        '${ApiEndpoints.preProxyUrl}${ApiEndpoints.preCapsuleStore}',
        data: payload,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Capsule storage failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Capsule storage error: $e');
    }
  }

  /// Register content on blockchain (ContentRegistry contract)
  Future<Map<String, dynamic>> _registerOnChain({
    required String ipfsCid,
    required String capsuleId,
    required BigInt price,
    required ContentMetadata metadata,
    required int fileSize,
    required Uint8List encryptedKey,
  }) async {
    try {
      // Load ContentRegistry ABI
      final contractAbi = await _loadContentRegistryAbi();

      final contract = DeployedContract(
        ContractAbi.fromJson(contractAbi, 'ContentRegistry'),
        EthereumAddress.fromHex(ContractAddresses.contentRegistry),
      );

      // Convert IPFS CID to bytes32 (contentHash)
      final contentHash = _ipfsCidToBytes32(ipfsCid);

      // Create metadata JSON and hash it
      final metadataJson = jsonEncode(metadata.toJson());
      final metadataBytes = utf8.encode(metadataJson);
      final metadataHashBytes = SymmetricCryptoService.hash(metadataBytes);
      final metadataHash = Uint8List.fromList(metadataHashBytes);

      // Use the actual encrypted AES key
      // Note: This is the raw key - in production PRE would encrypt it
      final encryptedKeyBytes = encryptedKey;

      // Map content type: Image=0, Video=1, Audio=2, Document=3, Other=4
      int contentTypeEnum = 0; // Default to Image
      switch (metadata.contentType.toLowerCase()) {
        case 'image':
        case 'photography':
        case 'art':
          contentTypeEnum = 0;
          break;
        case 'video':
          contentTypeEnum = 1;
          break;
        case 'music':
        case 'audio':
          contentTypeEnum = 2;
          break;
        case 'journal':
        case 'writing':
        case 'document':
          contentTypeEnum = 3;
          break;
        default:
          contentTypeEnum = 4;
      }

      // Access model: Free=0, OneTime=1, Subscription=2, PayPerView=3
      final accessModel = price == BigInt.zero ? 0 : 1; // Free or OneTime

      // Convert capsule ID to bytes32
      final capsuleHash = hexToBytes(capsuleId);

      // Get owner public key (for PRE)
      // For MVP: Use address as placeholder
      final ownerPublicKey = utf8.encode(_web3Service.userAddress.hex);

      // Debug logging
      print('🔍 Registration params:');
      print('  contentHash: ${contentHash.length} bytes');
      print('  metadataHash: ${metadataHash.length} bytes');
      print('  encryptedKey: ${encryptedKeyBytes.length} bytes');
      print('  fileSize: $fileSize');
      print('  contentType: $contentTypeEnum');
      print('  accessModel: $accessModel');
      print('  capsuleHash: ${capsuleHash.length} bytes');
      print('  ownerPublicKey: ${ownerPublicKey.length} bytes');
      print('  capsuleId: $capsuleId');

      // Send transaction to register content with PRE
      final txHash = await _web3Service.sendContractTransaction(
        contractAddress: ContractAddresses.contentRegistry,
        functionName: 'registerContentWithPRE',
        params: [
          contentHash,          // bytes32
          metadataHash,         // bytes32
          encryptedKeyBytes,    // bytes (actual key)
          BigInt.from(fileSize), // uint256 (actual file size)
          BigInt.from(contentTypeEnum),  // uint8
          BigInt.from(accessModel),  // uint8
          capsuleHash,          // bytes32
          ownerPublicKey,       // bytes
        ],
        abi: contractAbi,
      );

      // Wait for confirmation
      final receipt = await _web3Service.waitForReceipt(txHash);

      // Extract content ID from event logs
      // The ContentRegistered event emits: event ContentRegistered(uint256 indexed contentId, ...)
      // The contentId is in topics[1] (topics[0] is the event signature)
      int contentId = 0;
      if (receipt?.logs.isNotEmpty == true) {
        final log = receipt!.logs.first;
        if (log.topics != null && log.topics!.length > 1) {
          // Convert hex topic to integer contentId
          final hexContentId = log.topics![1];
          if (hexContentId != null) {
            contentId = BigInt.parse(hexContentId.replaceFirst('0x', ''), radix: 16).toInt();
          }
        }
      }

      return {
        'contentId': contentId,
        'txHash': txHash,
      };
    } catch (e) {
      throw Exception('Blockchain registration failed: $e');
    }
  }

  /// Convert IPFS CID (base58) to bytes32
  Uint8List _ipfsCidToBytes32(String cid) {
    // For MVP: Just hash the CID string
    // In production: Properly decode base58 CID
    final cidBytes = utf8.encode(cid);
    final hash = SymmetricCryptoService.hash(cidBytes);
    return Uint8List.fromList(hash);
  }

  /// Convert hex string to bytes
  Uint8List hexToBytes(String hex) {
    final hexClean = hex.startsWith('0x') ? hex.substring(2) : hex;
    final bytes = <int>[];
    for (int i = 0; i < hexClean.length; i += 2) {
      bytes.add(int.parse(hexClean.substring(i, i + 2), radix: 16));
    }
    // Pad to 32 bytes if needed
    while (bytes.length < 32) {
      bytes.insert(0, 0);
    }
    return Uint8List.fromList(bytes.take(32).toList());
  }

  /// Load ContentRegistry ABI
  Future<String> _loadContentRegistryAbi() async {
    // ABI for registerContentWithPRE function
    return jsonEncode([
      {
        "inputs": [
          {"name": "contentHash", "type": "bytes32"},
          {"name": "metadataHash", "type": "bytes32"},
          {"name": "encryptedKey", "type": "bytes"},
          {"name": "fileSize", "type": "uint256"},
          {"name": "contentType", "type": "uint8"},
          {"name": "accessModel", "type": "uint8"},
          {"name": "capsuleHash", "type": "bytes32"},
          {"name": "ownerPublicKey", "type": "bytes"}
        ],
        "name": "registerContentWithPRE",
        "outputs": [
          {"name": "contentId", "type": "uint256"}
        ],
        "stateMutability": "nonpayable",
        "type": "function"
      }
    ]);
  }

  /// Get user's uploaded content
  Future<List<Map<String, dynamic>>> getUserContent(EthereumAddress owner) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.getUserContents(owner.hex),
      );

      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<Map<String, dynamic>>.from(response.data);
        } else if (response.data is Map && response.data['contents'] != null) {
          return List<Map<String, dynamic>>.from(response.data['contents']);
        }
      }

      return [];
    } catch (e) {
      print('Error getting user content: $e');
      return [];
    }
  }

  /// Delete content (owner only)
  Future<bool> deleteContent(String contentId) async {
    try {
      // This would call a contract function to mark as deleted
      // For MVP, just return success
      return true;
    } catch (e) {
      print('Error deleting content: $e');
      return false;
    }
  }
}
