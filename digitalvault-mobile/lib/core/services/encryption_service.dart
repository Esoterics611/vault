import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Service for encrypting and decrypting content
class EncryptionService {
  /// Generate random AES-256 key
  static Uint8List generateKey() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    return secureRandom.nextBytes(32); // 256 bits
  }

  /// Generate random IV (Initialization Vector)
  static Uint8List generateIV() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    return secureRandom.nextBytes(16); // 128 bits
  }

  /// Encrypt content with AES-256-GCM
  static EncryptionResult encrypt(Uint8List plaintext, Uint8List key) {
    final iv = generateIV();

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          128, // tag length in bits
          iv,
          Uint8List(0), // additional data
        ),
      );

    final ciphertext = cipher.process(plaintext);

    return EncryptionResult(
      ciphertext: ciphertext,
      iv: iv,
      key: key,
    );
  }

  /// Decrypt content with AES-256-GCM
  static Uint8List decrypt(Uint8List ciphertext, Uint8List key, Uint8List iv) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          128,
          iv,
          Uint8List(0),
        ),
      );

    return cipher.process(ciphertext);
  }

  /// Derive key from password using PBKDF2
  static Uint8List deriveKey(String password, Uint8List salt, {int iterations = 10000}) {
    final generator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, 32));

    return generator.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Hash content with SHA-256
  static String hashContent(Uint8List content) {
    final digest = sha256.convert(content);
    return digest.toString();
  }

  /// Encrypt key with public key (for sharing encrypted content key)
  static Uint8List encryptKey(Uint8List key, RSAPublicKey publicKey) {
    final encryptor = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    return _processInBlocks(encryptor, key);
  }

  /// Decrypt key with private key
  static Uint8List decryptKey(Uint8List encryptedKey, RSAPrivateKey privateKey) {
    final decryptor = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    return _processInBlocks(decryptor, encryptedKey);
  }

  /// Process data in blocks (for RSA)
  static Uint8List _processInBlocks(AsymmetricBlockCipher engine, Uint8List input) {
    final numBlocks = input.length ~/ engine.inputBlockSize +
        ((input.length % engine.inputBlockSize != 0) ? 1 : 0);

    final output = BytesBuilder();

    for (var i = 0; i < numBlocks; i++) {
      final offset = i * engine.inputBlockSize;
      final chunkSize = (offset + engine.inputBlockSize <= input.length)
          ? engine.inputBlockSize
          : input.length - offset;

      output.add(engine.process(Uint8List.sublistView(input, offset, offset + chunkSize)));
    }

    return output.toBytes();
  }
}

/// Result of encryption operation
class EncryptionResult {
  final Uint8List ciphertext;
  final Uint8List iv;
  final Uint8List key;

  EncryptionResult({
    required this.ciphertext,
    required this.iv,
    required this.key,
  });

  /// Convert to base64 for storage/transmission
  Map<String, String> toBase64() {
    return {
      'ciphertext': base64Encode(ciphertext),
      'iv': base64Encode(iv),
      'key': base64Encode(key),
    };
  }

  /// Create from base64
  factory EncryptionResult.fromBase64(Map<String, String> data) {
    return EncryptionResult(
      ciphertext: base64Decode(data['ciphertext']!),
      iv: base64Decode(data['iv']!),
      key: base64Decode(data['key']!),
    );
  }
}
