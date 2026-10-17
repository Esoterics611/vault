import '../contracts/vault_token_contract.dart';
import '../contracts/content_registry_contract.dart';
import '../contracts/marketplace_contract.dart';
import '../contracts/dao_governor_contract.dart';
import '../constants/contract_addresses.dart';

/// Contract Service
///
/// Centralized service for managing all smart contract instances.
/// This service initializes contracts based on the current chain ID
/// and provides easy access to all contract instances.
///
/// Usage:
/// ```dart
/// final contractService = ContractService();
/// await contractService.initialize(chainId: 84532);
///
/// // Access contracts
/// final vltcBalance = await contractService.vaultToken.balanceOf(...);
/// await contractService.contentRegistry.registerContentWithPRE(...);
/// await contractService.marketplace.createListing(...);
/// ```
class ContractService {
  VaultTokenContract? _vaultToken;
  ContentRegistryContract? _contentRegistry;
  MarketplaceContract? _marketplace;
  DAOGovernorContract? _daoGovernor;

  int? _chainId;
  Map<String, String>? _addresses;

  /// Initialize all contracts for the specified chain
  ///
  /// Parameters:
  /// - chainId: The blockchain network ID (84532 for Base Sepolia)
  ///
  /// This method:
  /// 1. Gets contract addresses for the chain
  /// 2. Initializes all contract wrappers
  /// 3. Loads ABIs from assets
  /// 4. Creates contract instances
  ///
  /// Throws:
  /// - Exception if contracts not deployed on the specified chain
  /// - Exception if ABI files not found
  ///
  /// Example:
  /// ```dart
  /// final service = ContractService();
  /// try {
  ///   await service.initialize(chainId: 84532);
  ///   print('Contracts initialized for Base Sepolia');
  /// } catch (e) {
  ///   print('Failed to initialize contracts: $e');
  /// }
  /// ```
  /// Initialize in read-only mode at app startup (no wallet required)
  ///
  /// Allows reading from contracts (Marketplace listings, content browse)
  /// before the user connects their wallet. Call this during app startup.
  Future<void> initReadOnly({int chainId = 84532}) async {
    await initialize(chainId: chainId);
  }

  Future<void> initialize({required int chainId}) async {
    _chainId = chainId;
    _addresses = ContractAddresses.getAddresses(chainId);

    // Validate addresses
    _validateAddresses();

    // Initialize VaultToken
    _vaultToken = VaultTokenContract();
    await _vaultToken!.initialize(_addresses!['VaultToken']!);

    // Initialize ContentRegistry
    _contentRegistry = ContentRegistryContract();
    await _contentRegistry!.initialize(_addresses!['ContentRegistry']!);

    // Initialize Marketplace
    _marketplace = MarketplaceContract();
    await _marketplace!.initialize(_addresses!['Marketplace']!);

    // Initialize DAOGovernor (if deployed)
    if (_addresses!['DAOGovernor'] != null &&
        _addresses!['DAOGovernor'] != '0x0000000000000000000000000000000000000000') {
      _daoGovernor = DAOGovernorContract();
      await _daoGovernor!.initialize(_addresses!['DAOGovernor']!);
    }
  }

  /// Validate that all required contracts are deployed
  void _validateAddresses() {
    final required = ['VaultToken', 'ContentRegistry', 'Marketplace'];

    for (final name in required) {
      final address = _addresses![name];
      if (address == null || address == '0x0000000000000000000000000000000000000000') {
        throw Exception(
          '$name contract not deployed on chain $_chainId. '
          'Please deploy contracts first or check contract_addresses.dart',
        );
      }
    }
  }

  /// Get VaultToken contract instance
  ///
  /// Returns the initialized VaultToken contract wrapper.
  ///
  /// Throws:
  /// - StateError if contracts not initialized (call initialize() first)
  ///
  /// Example:
  /// ```dart
  /// final vaultToken = service.vaultToken;
  /// final balance = await web3.call(
  ///   contract: vaultToken.contract,
  ///   function: vaultToken.balanceOf,
  ///   params: [userAddress],
  /// );
  /// ```
  VaultTokenContract get vaultToken {
    if (_vaultToken == null) {
      throw StateError(
        'ContractService not initialized. Call initialize() first.',
      );
    }
    return _vaultToken!;
  }

  /// Get ContentRegistry contract instance
  ///
  /// Returns the initialized ContentRegistry contract wrapper.
  ///
  /// Throws:
  /// - StateError if contracts not initialized
  ///
  /// Example:
  /// ```dart
  /// final contentRegistry = service.contentRegistry;
  /// final tx = await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: contentRegistry.contract,
  ///     function: contentRegistry.registerContentWithPRE,
  ///     parameters: [...],
  ///   ),
  /// );
  /// ```
  ContentRegistryContract get contentRegistry {
    if (_contentRegistry == null) {
      throw StateError(
        'ContractService not initialized. Call initialize() first.',
      );
    }
    return _contentRegistry!;
  }

  /// Get Marketplace contract instance
  ///
  /// Returns the initialized Marketplace contract wrapper.
  ///
  /// Throws:
  /// - StateError if contracts not initialized
  ///
  /// Example:
  /// ```dart
  /// final marketplace = service.marketplace;
  /// final listings = await web3.call(
  ///   contract: marketplace.contract,
  ///   function: marketplace.getActiveListings,
  ///   params: [],
  /// );
  /// ```
  MarketplaceContract get marketplace {
    if (_marketplace == null) {
      throw StateError(
        'ContractService not initialized. Call initialize() first.',
      );
    }
    return _marketplace!;
  }

  /// Alias for marketplace getter
  MarketplaceContract get marketplaceContract => marketplace;

  /// Alias for contentRegistry getter
  ContentRegistryContract get contentRegistryContract => contentRegistry;

  /// Alias for vaultToken getter
  VaultTokenContract get vaultTokenContract => vaultToken;

  /// Get DAOGovernor contract instance
  ///
  /// Returns the initialized DAOGovernor contract wrapper.
  ///
  /// Throws:
  /// - StateError if contracts not initialized or DAO not deployed
  ///
  /// Example:
  /// ```dart
  /// final daoGovernor = service.daoGovernor;
  /// final proposalState = await web3.call(
  ///   contract: daoGovernor.contract,
  ///   function: daoGovernor.state,
  ///   params: [proposalId],
  /// );
  /// ```
  DAOGovernorContract get daoGovernor {
    if (_daoGovernor == null) {
      throw StateError(
        'DAOGovernor contract not initialized. Check if DAO is deployed on this network.',
      );
    }
    return _daoGovernor!;
  }

  /// Get current chain ID
  ///
  /// Returns the chain ID that contracts were initialized with.
  ///
  /// Returns null if not initialized.
  int? get chainId => _chainId;

  /// Get contract addresses for current chain
  ///
  /// Returns a map of contract names to addresses.
  ///
  /// Returns null if not initialized.
  Map<String, String>? get addresses => _addresses;

  /// Check if contracts are initialized
  ///
  /// Returns true if initialize() has been called successfully.
  bool get isInitialized =>
      _vaultToken != null && _contentRegistry != null && _marketplace != null;

  /// Check if DAO is initialized
  ///
  /// Returns true if DAOGovernor contract is initialized.
  bool get isDaoInitialized => _daoGovernor != null;

  /// Get all contract addresses as formatted string
  ///
  /// Useful for debugging or displaying to users.
  ///
  /// Example output:
  /// ```
  /// VaultToken: 0x9583...B79970D3
  /// ContentRegistry: 0xd469...41C41f0
  /// Marketplace: 0xC763...eba91c5
  /// ```
  String getContractInfo() {
    if (!isInitialized) {
      return 'Contracts not initialized';
    }

    final buffer = StringBuffer();
    buffer.writeln('Chain ID: $_chainId');
    buffer.writeln('Network: ${_getNetworkName()}');
    buffer.writeln();

    _addresses!.forEach((name, address) {
      if (address != '0x0000000000000000000000000000000000000000') {
        final short = '${address.substring(0, 6)}...${address.substring(address.length - 8)}';
        buffer.writeln('$name: $short');
      }
    });

    return buffer.toString();
  }

  /// Get network name from chain ID
  String _getNetworkName() {
    switch (_chainId) {
      case 8453:
        return 'Base Mainnet';
      case 84532:
        return 'Base Sepolia Testnet';
      case 31337:
        return 'Localhost (Hardhat)';
      default:
        return 'Unknown Network';
    }
  }

  /// Get block explorer URL for an address
  ///
  /// Returns the Basescan URL for viewing an address.
  ///
  /// Parameters:
  /// - address: The contract or account address
  ///
  /// Example:
  /// ```dart
  /// final url = service.getExplorerUrl(marketplace.address);
  /// // Returns: https://sepolia.basescan.org/address/0xC763...
  /// ```
  String getExplorerUrl(String address) {
    switch (_chainId) {
      case 8453:
        return 'https://basescan.org/address/$address';
      case 84532:
        return 'https://sepolia.basescan.org/address/$address';
      default:
        return 'Unknown explorer';
    }
  }

  /// Get block explorer URL for a transaction
  ///
  /// Returns the Basescan URL for viewing a transaction.
  ///
  /// Parameters:
  /// - txHash: The transaction hash
  ///
  /// Example:
  /// ```dart
  /// final url = service.getTransactionUrl(txHash);
  /// // Returns: https://sepolia.basescan.org/tx/0x...
  /// ```
  String getTransactionUrl(String txHash) {
    switch (_chainId) {
      case 8453:
        return 'https://basescan.org/tx/$txHash';
      case 84532:
        return 'https://sepolia.basescan.org/tx/$txHash';
      default:
        return 'Unknown explorer';
    }
  }

  /// Reset the service
  ///
  /// Clears all contract instances. Call initialize() again to reinitialize.
  ///
  /// Useful when switching networks.
  void reset() {
    _vaultToken = null;
    _contentRegistry = null;
    _marketplace = null;
    _daoGovernor = null;
    _chainId = null;
    _addresses = null;
  }
}
