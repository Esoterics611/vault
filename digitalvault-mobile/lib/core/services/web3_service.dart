import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import '../constants/contract_addresses.dart';
import 'ethereum_bridge.dart';

/// Service for interacting with blockchain via Web3
class Web3Service {
  Web3Client? _clientNullable;
  late Web3Client _client;
  late EthereumAddress _userAddress;
  late Credentials _credentials;
  int _chainId = 84532; // Default to Base Sepolia (production testnet)
  bool _isInitialized = false;
  bool _isReadOnly = false;
  bool _isBrowserWallet = false; // true when connected via window.ethereum

  // RPC URLs
  static const Map<int, String> rpcUrls = {
    8453: 'https://mainnet.base.org',
    84532: 'https://sepolia.base.org',
    31337: 'http://127.0.0.1:8545',
  };

  /// Initialize in read-only mode (no private key required)
  ///
  /// Allows contract reads (view functions) before a wallet is connected.
  /// This is a lightweight, synchronous-compatible init — no async needed.
  void initReadOnly({int chainId = 84532}) {
    if (_isInitialized) return; // Already initialized (wallet or read-only)
    _chainId = chainId;
    final rpcUrl = rpcUrls[chainId] ?? rpcUrls[31337]!;
    _client = Web3Client(rpcUrl, http.Client());
    _clientNullable = _client;
    _isReadOnly = true;
    _isInitialized = true;
  }

  /// Ensure initialized in read-only mode if not already initialized
  ///
  /// Call this at the start of any read operation to guarantee a Web3Client
  /// exists, even before the user connects a wallet.
  void ensureReadOnly({int chainId = 84532}) => initReadOnly(chainId: chainId);

  /// Initialize Web3 service with a private key (mobile / dev use).
  Future<void> initialize({
    required String privateKey,
    int chainId = 84532,
  }) async {
    _chainId = chainId;
    final rpcUrl = rpcUrls[chainId] ?? rpcUrls[84532]!;
    _client = Web3Client(rpcUrl, http.Client());
    _clientNullable = _client;
    _credentials = EthPrivateKey.fromHex(privateKey);
    _userAddress = _credentials.address;
    _isBrowserWallet = false;
    _isReadOnly = false;
    _isInitialized = true;
  }

  /// Initialize Web3 service using an injected browser wallet (MetaMask etc.).
  ///
  /// The [address] comes from [EthereumBridge.requestAccounts()].
  /// Read operations use the public RPC; write operations go through MetaMask.
  Future<void> initWithBrowserWallet({
    required String address,
    int chainId = 84532,
  }) async {
    _chainId = chainId;
    final rpcUrl = rpcUrls[chainId] ?? rpcUrls[84532]!;
    _client = Web3Client(rpcUrl, http.Client());
    _clientNullable = _client;
    _userAddress = EthereumAddress.fromHex(address);
    _isBrowserWallet = true;
    _isReadOnly = false;
    _isInitialized = true;
  }

  /// Whether service is read-only (no wallet connected)
  bool get isReadOnly => _isReadOnly;

  /// Whether connected via a browser-injected wallet (MetaMask etc.)
  bool get isBrowserWallet => _isBrowserWallet;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Get current user address (nullable)
  EthereumAddress? get userAddressOrNull => _isInitialized ? _userAddress : null;

  /// Get current user address (throws if not initialized)
  EthereumAddress get userAddress {
    if (!_isInitialized) {
      throw StateError('Web3Service not initialized. Call initialize() first.');
    }
    return _userAddress;
  }

  /// Get ETH balance
  Future<EtherAmount> getBalance() async {
    return await _client.getBalance(_userAddress);
  }

  /// Get ERC20 token balance
  Future<BigInt> getTokenBalance(String tokenAddress) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(_erc20Abi, 'ERC20'),
      EthereumAddress.fromHex(tokenAddress),
    );

    final balanceFunction = contract.function('balanceOf');
    final result = await _client.call(
      contract: contract,
      function: balanceFunction,
      params: [_userAddress],
    );

    return result.first as BigInt;
  }

  /// Send transaction
  Future<String> sendTransaction({
    required EthereumAddress to,
    required EtherAmount value,
    Uint8List? data,
  }) async {
    final txHash = await _client.sendTransaction(
      _credentials,
      Transaction(
        to: to,
        value: value,
        data: data,
      ),
      chainId: _chainId,
    );

    return txHash;
  }

  /// Call contract function (read-only)
  Future<List<dynamic>> callContractFunction({
    required String contractAddress,
    required String functionName,
    required List<dynamic> params,
    required String abi,
  }) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(abi, 'Contract'),
      EthereumAddress.fromHex(contractAddress),
    );

    final function = contract.function(functionName);
    final result = await _client.call(
      contract: contract,
      function: function,
      params: params,
    );

    return result;
  }

  /// Send contract transaction (write)
  Future<String> sendContractTransaction({
    required String contractAddress,
    required String functionName,
    required List<dynamic> params,
    required String abi,
    EtherAmount? value,
  }) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(abi, 'Contract'),
      EthereumAddress.fromHex(contractAddress),
    );
    final function = contract.function(functionName);
    return _sendContractCall(
      contract: contract,
      function: function,
      parameters: params,
      value: value,
    );
  }

  /// Wait for transaction receipt
  Future<TransactionReceipt?> waitForReceipt(String txHash) async {
    TransactionReceipt? receipt;
    int attempts = 0;
    const maxAttempts = 30;

    while (receipt == null && attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 2));
      receipt = await _client.getTransactionReceipt(txHash);
      attempts++;
    }

    return receipt;
  }

  /// Call a contract function (read-only)
  ///
  /// Generic method to call any contract function without sending a transaction.
  ///
  /// Parameters:
  /// - contract: The deployed contract instance
  /// - function: The contract function to call
  /// - params: Function parameters
  ///
  /// Returns: Function return values
  Future<List<dynamic>> call({
    required DeployedContract contract,
    required ContractFunction function,
    required List<dynamic> params,
  }) async {
    return await _client.call(
      contract: contract,
      function: function,
      params: params,
    );
  }

  /// Send a contract transaction
  ///
  /// Generic method to send a transaction to a contract function.
  /// Routes through MetaMask when running on web with a browser wallet.
  Future<String> sendContract({
    required DeployedContract contract,
    required ContractFunction function,
    required List<dynamic> parameters,
    EtherAmount? value,
  }) {
    return _sendContractCall(
      contract: contract,
      function: function,
      parameters: parameters,
      value: value,
    );
  }

  // ---------------------------------------------------------------------------
  // Internal: unified send path — private key OR browser wallet
  // ---------------------------------------------------------------------------
  Future<String> _sendContractCall({
    required DeployedContract contract,
    required ContractFunction function,
    required List<dynamic> parameters,
    EtherAmount? value,
  }) async {
    if (_isBrowserWallet && kIsWeb) {
      // ABI-encode the call locally, then hand it to MetaMask.
      final callData = function.encodeCall(parameters);
      final dataHex =
          '0x${callData.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      final valueHex = value != null
          ? '0x${value.getInWei.toRadixString(16)}'
          : '0x0';
      return EthereumBridge.sendTransaction(
        to: contract.address.hex,
        dataHex: dataHex,
        valueHex: valueHex,
        from: _userAddress.hex,
      );
    }

    // Private-key path (mobile / dev)
    return await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: contract,
        function: function,
        parameters: parameters,
        value: value,
      ),
      chainId: _chainId,
    );
  }

  /// Estimate gas for a contract transaction
  ///
  /// Estimates the gas required for a transaction before sending it.
  ///
  /// Parameters:
  /// - contract: The deployed contract instance
  /// - function: The contract function to call
  /// - parameters: Function parameters
  /// - value: ETH value to send (optional)
  ///
  /// Returns: Estimated gas amount
  Future<BigInt> estimateGas({
    required DeployedContract contract,
    required ContractFunction function,
    required List<dynamic> parameters,
    EtherAmount? value,
  }) async {
    return await _client.estimateGas(
      sender: _userAddress,
      to: contract.address,
      data: function.encodeCall(parameters),
      value: value,
    );
  }

  /// Get current gas price
  ///
  /// Returns the current gas price from the network.
  Future<EtherAmount> getGasPrice() async {
    return await _client.getGasPrice();
  }

  /// Get transaction count (nonce) for address
  ///
  /// Returns the number of transactions sent from an address.
  /// Used for determining the nonce for the next transaction.
  Future<int> getTransactionCount([EthereumAddress? address]) async {
    return await _client.getTransactionCount(address ?? _userAddress);
  }

  /// Get current block number
  ///
  /// Returns the latest block number from the network.
  Future<int> getBlockNumber() async {
    return await _client.getBlockNumber();
  }

  /// Get Web3Client instance
  ///
  /// Returns the underlying Web3Client for advanced operations.
  Web3Client get client => _client;

  /// Get credentials
  ///
  /// Returns the credentials for signing transactions.
  Credentials get credentials => _credentials;

  /// Get chain ID
  ///
  /// Returns the current chain ID.
  int get chainId => _chainId;

  /// Dispose resources
  void dispose() {
    _client.dispose();
  }

  // Minimal ERC20 ABI for balance check
  static const String _erc20Abi = '''
  [
    {
      "constant": true,
      "inputs": [{"name": "_owner", "type": "address"}],
      "name": "balanceOf",
      "outputs": [{"name": "balance", "type": "uint256"}],
      "type": "function"
    }
  ]
  ''';
}
