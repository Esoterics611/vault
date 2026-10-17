// Mobile stub — EthereumBridge is not available on non-web platforms.
// All methods throw; callers should gate on kIsWeb before calling.

class EthereumBridge {
  static bool get isAvailable => false;

  static Future<String> requestAccounts() =>
      throw UnsupportedError('EthereumBridge is only available on web.');

  static Future<int> getChainId() =>
      throw UnsupportedError('EthereumBridge is only available on web.');

  static Future<void> switchToBaseSepolia() =>
      throw UnsupportedError('EthereumBridge is only available on web.');

  static Future<String> sendTransaction({
    required String to,
    required String dataHex,
    String valueHex = '0x0',
    required String from,
  }) =>
      throw UnsupportedError('EthereumBridge is only available on web.');
}
