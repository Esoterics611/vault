import 'dart:typed_data';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto;

/// Result of encryption operation
class EncryptionResult {
  final Uint8List encryptedData;
  final Uint8List key; // AES-256 key (32 bytes)
  final Uint8List nonce; // IV/Nonce (12 bytes for GCM)
  final Uint8List mac; // Authentication tag

  EncryptionResult({
    required this.encryptedData,
    required this.key,
    required this.nonce,
    required this.mac,
  });

  /// Total size of encrypted package
  int get totalSize => encryptedData.length + nonce.length + mac.length;

  /// Combine all parts for storage (nonce + ciphertext + mac)
  Uint8List toBytes() {
    final buffer = BytesBuilder();
    buffer.add(nonce);
    buffer.add(encryptedData);
    buffer.add(mac);
    return buffer.toBytes();
  }

  /// Parse from combined bytes
  static EncryptionResult fromBytes(Uint8List bytes, Uint8List key) {
    if (bytes.length < 28) {
      // 12 (nonce) + 16 (mac minimum)
      throw Exception('Invalid encrypted data: too short');
    }

    final nonce = bytes.sublist(0, 12);
    final mac = bytes.sublist(bytes.length - 16);
    final encryptedData = bytes.sublist(12, bytes.length - 16);

    return EncryptionResult(
      encryptedData: encryptedData,
      key: key,
      nonce: nonce,
      mac: mac,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': base64Encode(key),
        'nonce': base64Encode(nonce),
        'mac': base64Encode(mac),
        'encryptedDataSize': encryptedData.length,
      };
}

/// Symmetric Encryption Service using AES-256-GCM
///
/// Provides secure encryption/decryption for content files before upload.
/// Uses AES-256-GCM for authenticated encryption.
class SymmetricCryptoService {
  static final _algorithm = AesGcm.with256bits();

  /// Generate a random AES-256 key (32 bytes)
  static Future<Uint8List> generateKey() async {
    final secretKey = await _algorithm.newSecretKey();
    final keyBytes = await secretKey.extractBytes();
    return Uint8List.fromList(keyBytes);
  }

  /// Generate a random nonce/IV (12 bytes for GCM)
  static Uint8List generateNonce() {
    final nonce = _algorithm.newNonce();
    return Uint8List.fromList(nonce);
  }

  /// Encrypt data with AES-256-GCM
  ///
  /// Parameters:
  /// - data: Raw data to encrypt
  /// - key: Optional AES-256 key (generates new if not provided)
  ///
  /// Returns: EncryptionResult with encrypted data and metadata
  static Future<EncryptionResult> encrypt({
    required Uint8List data,
    Uint8List? key,
  }) async {
    try {
      // Generate key if not provided
      final encryptionKey = key ?? await generateKey();

      // Validate key size
      if (encryptionKey.length != 32) {
        throw Exception('Invalid key size: expected 32 bytes, got ${encryptionKey.length}');
      }

      // Create SecretKey from bytes
      final secretKey = SecretKey(encryptionKey);

      // Generate nonce
      final nonce = generateNonce();

      // Encrypt data
      final secretBox = await _algorithm.encrypt(
        data,
        secretKey: secretKey,
        nonce: nonce,
      );

      // Extract ciphertext and MAC
      final cipherText = Uint8List.fromList(secretBox.cipherText);
      final mac = Uint8List.fromList(secretBox.mac.bytes);

      return EncryptionResult(
        encryptedData: cipherText,
        key: encryptionKey,
        nonce: nonce,
        mac: mac,
      );
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  /// Decrypt data with AES-256-GCM
  ///
  /// Parameters:
  /// - encryptedData: The ciphertext
  /// - key: AES-256 key used for encryption
  /// - nonce: Nonce/IV used during encryption
  /// - mac: Authentication tag
  ///
  /// Returns: Decrypted data
  static Future<Uint8List> decrypt({
    required Uint8List encryptedData,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List mac,
  }) async {
    try {
      // Validate inputs
      if (key.length != 32) {
        throw Exception('Invalid key size: expected 32 bytes');
      }
      if (nonce.length != 12) {
        throw Exception('Invalid nonce size: expected 12 bytes');
      }
      if (mac.length != 16) {
        throw Exception('Invalid MAC size: expected 16 bytes');
      }

      // Create SecretKey and SecretBox
      final secretKey = SecretKey(key);
      final secretBox = SecretBox(
        encryptedData,
        nonce: nonce,
        mac: Mac(mac),
      );

      // Decrypt
      final decryptedData = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return Uint8List.fromList(decryptedData);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  /// Decrypt from combined bytes (nonce + ciphertext + mac)
  static Future<Uint8List> decryptFromBytes({
    required Uint8List encryptedBytes,
    required Uint8List key,
  }) async {
    final result = EncryptionResult.fromBytes(encryptedBytes, key);
    return decrypt(
      encryptedData: result.encryptedData,
      key: key,
      nonce: result.nonce,
      mac: result.mac,
    );
  }

  /// Encrypt a string (UTF-8)
  static Future<EncryptionResult> encryptString({
    required String data,
    Uint8List? key,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(data));
    return encrypt(data: bytes, key: key);
  }

  /// Decrypt to string (UTF-8)
  static Future<String> decryptString({
    required Uint8List encryptedData,
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List mac,
  }) async {
    final decryptedBytes = await decrypt(
      encryptedData: encryptedData,
      key: key,
      nonce: nonce,
      mac: mac,
    );
    return utf8.decode(decryptedBytes);
  }

  /// Hash data with SHA-256 (for integrity checks)
  static Uint8List hash(Uint8List data) {
    final digest = crypto.sha256.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  /// Hash string with SHA-256
  static String hashString(String data) {
    final bytes = utf8.encode(data);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  /// Derive a key from password using PBKDF2 (for future use)
  static Future<Uint8List> deriveKeyFromPassword({
    required String password,
    required Uint8List salt,
    int iterations = 100000,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    final keyBytes = await secretKey.extractBytes();
    return Uint8List.fromList(keyBytes);
  }

  /// Generate salt for PBKDF2
  static Uint8List generateSalt({int length = 32}) {
    final random = List<int>.generate(length, (i) => DateTime.now().microsecondsSinceEpoch % 256);
    return Uint8List.fromList(random);
  }

  /// Convert bytes to hex string
  static String toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Convert hex string to bytes
  static Uint8List fromHex(String hex) {
    if (hex.length % 2 != 0) {
      throw Exception('Invalid hex string');
    }
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }
}
