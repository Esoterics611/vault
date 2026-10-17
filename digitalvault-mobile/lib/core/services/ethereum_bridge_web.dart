// Web implementation of EthereumBridge — calls window.ethereumBridge via dart:js_util.
// Only compiled on the web target.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_util' as js_util;

class EthereumBridge {
  static dynamic get _bridge =>
      js_util.getProperty(js_util.globalThis, 'ethereumBridge');

  /// True if MetaMask (or another injected provider) is present.
  static bool get isAvailable {
    try {
      return js_util.callMethod(_bridge, 'isAvailable', []) as bool;
    } catch (_) {
      return false;
    }
  }

  /// Prompt the user to connect and return the selected account address.
  static Future<String> requestAccounts() {
    return js_util.promiseToFuture<String>(
      js_util.callMethod(_bridge, 'requestAccounts', []),
    );
  }

  /// Return the wallet's current chain ID.
  static Future<int> getChainId() async {
    final result = await js_util.promiseToFuture<dynamic>(
      js_util.callMethod(_bridge, 'getChainId', []),
    );
    return (result as num).toInt();
  }

  /// Ask MetaMask to switch to (or add) Base Sepolia.
  static Future<void> switchToBaseSepolia() {
    return js_util.promiseToFuture<void>(
      js_util.callMethod(_bridge, 'switchToBaseSepolia', []),
    );
  }

  /// Send a transaction through MetaMask.
  /// [dataHex]  — ABI-encoded calldata, 0x-prefixed (use '0x' for plain ETH transfers).
  /// [valueHex] — wei as 0x-prefixed hex (use '0x0' if no ETH is being sent).
  static Future<String> sendTransaction({
    required String to,
    required String dataHex,
    String valueHex = '0x0',
    required String from,
  }) {
    return js_util.promiseToFuture<String>(
      js_util.callMethod(_bridge, 'sendTransaction', [to, dataHex, valueHex, from]),
    );
  }
}
