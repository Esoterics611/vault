import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/symmetric_crypto_service.dart';

/// Owned Content Item
///
/// Represents a content item that the user owns or has purchased.
class OwnedContent {
  final String contentId;
  final String title;
  final String? description;
  final String ipfsCid;
  final String category;
  final BigInt fileSize;
  final DateTime acquiredDate;
  final String encryptedKey; // Re-encrypted key for buyer, or original for owner
  final bool isOriginalOwner;
  final String? localFilePath; // Path if downloaded locally

  OwnedContent({
    required this.contentId,
    required this.title,
    this.description,
    required this.ipfsCid,
    required this.category,
    required this.fileSize,
    required this.acquiredDate,
    required this.encryptedKey,
    required this.isOriginalOwner,
    this.localFilePath,
  });

  Map<String, dynamic> toJson() => {
        'contentId': contentId,
        'title': title,
        'description': description,
        'ipfsCid': ipfsCid,
        'category': category,
        'fileSize': fileSize.toString(),
        'acquiredDate': acquiredDate.toIso8601String(),
        'encryptedKey': encryptedKey,
        'isOriginalOwner': isOriginalOwner,
        'localFilePath': localFilePath,
      };

  factory OwnedContent.fromJson(Map<String, dynamic> json) => OwnedContent(
        contentId: json['contentId'],
        title: json['title'],
        description: json['description'],
        ipfsCid: json['ipfsCid'],
        category: json['category'],
        fileSize: BigInt.parse(json['fileSize']),
        acquiredDate: DateTime.parse(json['acquiredDate']),
        encryptedKey: json['encryptedKey'],
        isOriginalOwner: json['isOriginalOwner'] ?? false,
        localFilePath: json['localFilePath'],
      );

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

  /// Check if content is downloaded locally
  bool get isDownloaded => localFilePath != null && File(localFilePath!).existsSync();
}

/// Download Progress Callback
typedef DownloadProgressCallback = void Function(int downloaded, int total);

/// Content Access Service
///
/// Handles content decryption, downloading, and local storage.
/// Manages the user's owned content library.
class ContentAccessService {
  final SymmetricCryptoService cryptoService;
  final String ipfsGatewayUrl;

  // Storage keys
  static const String _ownedContentKey = 'owned_content_library';
  static const String _encryptedKeysPrefix = 'content_key_';

  ContentAccessService({
    required this.cryptoService,
    this.ipfsGatewayUrl = 'http://10.0.0.2:3000', // Production-ready host IP
  });

  /// Add content to owned library
  ///
  /// Called after purchasing or uploading content.
  ///
  /// Parameters:
  /// - content: The owned content item
  /// - encryptedKey: The encryption key (re-encrypted for buyer)
  Future<void> addToLibrary({
    required OwnedContent content,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing library
      final library = await getOwnedContent();

      // Check if already exists
      final existingIndex =
          library.indexWhere((item) => item.contentId == content.contentId);

      if (existingIndex >= 0) {
        // Update existing
        library[existingIndex] = content;
      } else {
        // Add new
        library.add(content);
      }

      // Save library
      final libraryJson = library.map((item) => item.toJson()).toList();
      await prefs.setString(_ownedContentKey, json.encode(libraryJson));

      // Store encrypted key separately (more secure)
      await prefs.setString(
        '$_encryptedKeysPrefix${content.contentId}',
        content.encryptedKey,
      );
    } catch (e) {
      throw Exception('Failed to add to library: $e');
    }
  }

  /// Get all owned content
  Future<List<OwnedContent>> getOwnedContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final libraryString = prefs.getString(_ownedContentKey);

      if (libraryString == null) {
        return [];
      }

      final libraryJson = json.decode(libraryString) as List<dynamic>;
      return libraryJson
          .map((item) => OwnedContent.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get owned content: $e');
    }
  }

  /// Get single owned content item
  Future<OwnedContent?> getOwnedContentById(String contentId) async {
    final library = await getOwnedContent();
    try {
      return library.firstWhere((item) => item.contentId == contentId);
    } catch (e) {
      return null;
    }
  }

  /// Remove content from library
  Future<void> removeFromLibrary(String contentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final library = await getOwnedContent();

      // Remove from library
      library.removeWhere((item) => item.contentId == contentId);

      // Save updated library
      final libraryJson = library.map((item) => item.toJson()).toList();
      await prefs.setString(_ownedContentKey, json.encode(libraryJson));

      // Remove encrypted key
      await prefs.remove('$_encryptedKeysPrefix$contentId');

      // Delete local file if exists
      final content = await getOwnedContentById(contentId);
      if (content?.localFilePath != null) {
        final file = File(content!.localFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      throw Exception('Failed to remove from library: $e');
    }
  }

  /// Download and decrypt content
  ///
  /// Downloads encrypted content from IPFS, decrypts it, and saves locally.
  ///
  /// Parameters:
  /// - contentId: The content ID
  /// - onProgress: Optional callback for download progress
  ///
  /// Returns path to decrypted local file.
  Future<String> downloadAndDecrypt({
    required String contentId,
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      // Get owned content info
      final content = await getOwnedContentById(contentId);
      if (content == null) {
        throw Exception('Content not found in library');
      }

      // Check if already downloaded
      if (content.isDownloaded) {
        return content.localFilePath!;
      }

      // Download encrypted content from IPFS
      final encryptedData = await _downloadFromIPFS(
        content.ipfsCid,
        onProgress: onProgress,
      );

      // Get encryption key
      final prefs = await SharedPreferences.getInstance();
      final encryptedKeyHex =
          prefs.getString('$_encryptedKeysPrefix$contentId');

      if (encryptedKeyHex == null) {
        throw Exception('Encryption key not found');
      }

      // For purchased content, the key is re-encrypted
      // For owned content, we have the original key
      // For now, assuming we have the decryption key
      // TODO: Implement PRE decryption for purchased content

      final keyBytes = _hexToBytes(encryptedKeyHex);

      // Parse encrypted data (nonce + ciphertext + mac)
      // Format: [12 bytes nonce][N bytes ciphertext][16 bytes mac]
      if (encryptedData.length < 28) {
        throw Exception('Invalid encrypted data format');
      }

      final nonce = encryptedData.sublist(0, 12);
      final mac = encryptedData.sublist(encryptedData.length - 16);
      final ciphertext = encryptedData.sublist(12, encryptedData.length - 16);

      // Decrypt content
      final decryptedData = await SymmetricCryptoService.decrypt(
        encryptedData: ciphertext,
        key: keyBytes,
        nonce: nonce,
        mac: mac,
      );

      // Save decrypted file locally
      final localPath = await _saveToLocal(
        contentId: contentId,
        data: decryptedData,
        originalFilename: content.title,
      );

      // Update library with local path
      final updatedContent = OwnedContent(
        contentId: content.contentId,
        title: content.title,
        description: content.description,
        ipfsCid: content.ipfsCid,
        category: content.category,
        fileSize: content.fileSize,
        acquiredDate: content.acquiredDate,
        encryptedKey: content.encryptedKey,
        isOriginalOwner: content.isOriginalOwner,
        localFilePath: localPath,
      );

      await addToLibrary(content: updatedContent);

      return localPath;
    } catch (e) {
      throw Exception('Failed to download and decrypt: $e');
    }
  }

  /// Download encrypted content from IPFS
  Future<Uint8List> _downloadFromIPFS(
    String ipfsCid, {
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      final url = '$ipfsGatewayUrl/api/ipfs/content/$ipfsCid';
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('IPFS download failed: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      int downloaded = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        downloaded += chunk.length;
        onProgress?.call(downloaded, contentLength);
      }

      return Uint8List.fromList(bytes);
    } catch (e) {
      throw Exception('Failed to download from IPFS: $e');
    }
  }

  /// Save decrypted data to local storage
  Future<String> _saveToLocal({
    required String contentId,
    required Uint8List data,
    required String originalFilename,
  }) async {
    try {
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final contentDir = Directory('${directory.path}/content');

      // Create content directory if it doesn't exist
      if (!await contentDir.exists()) {
        await contentDir.create(recursive: true);
      }

      // Generate filename
      final extension = _getFileExtension(originalFilename);
      final filename = 'content_$contentId$extension';
      final filePath = '${contentDir.path}/$filename';

      // Write file
      final file = File(filePath);
      await file.writeAsBytes(data);

      return filePath;
    } catch (e) {
      throw Exception('Failed to save to local: $e');
    }
  }

  /// Get file extension from filename
  String _getFileExtension(String filename) {
    final parts = filename.split('.');
    if (parts.length > 1) {
      return '.${parts.last}';
    }
    return '';
  }

  /// Delete local file
  Future<void> deleteLocalFile(String contentId) async {
    try {
      final content = await getOwnedContentById(contentId);
      if (content?.localFilePath != null) {
        final file = File(content!.localFilePath!);
        if (await file.exists()) {
          await file.delete();
        }

        // Update library
        final updatedContent = OwnedContent(
          contentId: content.contentId,
          title: content.title,
          description: content.description,
          ipfsCid: content.ipfsCid,
          category: content.category,
          fileSize: content.fileSize,
          acquiredDate: content.acquiredDate,
          encryptedKey: content.encryptedKey,
          isOriginalOwner: content.isOriginalOwner,
          localFilePath: null, // Clear local path
        );

        await addToLibrary(content: updatedContent);
      }
    } catch (e) {
      throw Exception('Failed to delete local file: $e');
    }
  }

  /// Get total storage used
  Future<int> getTotalStorageUsed() async {
    try {
      final library = await getOwnedContent();
      int total = 0;

      for (final content in library) {
        if (content.localFilePath != null) {
          final file = File(content.localFilePath!);
          if (await file.exists()) {
            total += await file.length();
          }
        }
      }

      return total;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all local files
  Future<void> clearAllLocalFiles() async {
    try {
      final library = await getOwnedContent();

      for (final content in library) {
        await deleteLocalFile(content.contentId);
      }
    } catch (e) {
      throw Exception('Failed to clear local files: $e');
    }
  }

  /// Check if content can be accessed
  ///
  /// Verifies that user owns the content and has the decryption key.
  Future<bool> canAccess(String contentId) async {
    try {
      final content = await getOwnedContentById(contentId);
      if (content == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final hasKey = prefs.containsKey('$_encryptedKeysPrefix$contentId');

      return hasKey;
    } catch (e) {
      return false;
    }
  }

  /// Convert hex string to bytes
  Uint8List _hexToBytes(String hex) {
    final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;
    final bytes = Uint8List(cleanHex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  /// Get content by category
  Future<List<OwnedContent>> getContentByCategory(String category) async {
    final library = await getOwnedContent();
    return library.where((item) => item.category == category).toList();
  }

  /// Get downloaded content only
  Future<List<OwnedContent>> getDownloadedContent() async {
    final library = await getOwnedContent();
    return library.where((item) => item.isDownloaded).toList();
  }

  /// Get content owned vs purchased
  Future<Map<String, List<OwnedContent>>> getContentByOwnership() async {
    final library = await getOwnedContent();

    return {
      'owned': library.where((item) => item.isOriginalOwner).toList(),
      'purchased': library.where((item) => !item.isOriginalOwner).toList(),
    };
  }
}
