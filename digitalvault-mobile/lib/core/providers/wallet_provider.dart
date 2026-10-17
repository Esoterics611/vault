import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3dart/web3dart.dart';
import '../services/web3_service.dart';
import '../services/contract_service.dart';
import '../services/ethereum_bridge.dart';
import '../constants/contract_addresses.dart';

/// Wallet state model
class WalletState {
  final String? address;
  final EtherAmount? ethBalance;
  final BigInt? vltcBalance;
  final bool isConnected;
  final bool isLoading;
  final String? error;

  const WalletState({
    this.address,
    this.ethBalance,
    this.vltcBalance,
    this.isConnected = false,
    this.isLoading = false,
    this.error,
  });

  WalletState copyWith({
    String? address,
    EtherAmount? ethBalance,
    BigInt? vltcBalance,
    bool? isConnected,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      address: address ?? this.address,
      ethBalance: ethBalance ?? this.ethBalance,
      vltcBalance: vltcBalance ?? this.vltcBalance,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  String get formattedEthBalance {
    if (ethBalance == null) return '0.0';
    return ethBalance!.getValueInUnit(EtherUnit.ether).toStringAsFixed(4);
  }

  String get formattedVltcBalance {
    if (vltcBalance == null) return '0';
    final value = vltcBalance! / BigInt.from(10).pow(18);
    return value.toString();
  }
}

/// Wallet provider
class WalletNotifier extends StateNotifier<WalletState> {
  final Web3Service _web3Service;
  final ContractService _contractService;

  WalletNotifier(this._web3Service, this._contractService) : super(const WalletState());

  /// Connect wallet with private key
  Future<void> connectWallet(String privateKey, {int chainId = 84532}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Initialize Web3 service
      await _web3Service.initialize(
        privateKey: privateKey,
        chainId: chainId,
      );

      // Initialize Contract service with same chainId
      await _contractService.initialize(chainId: chainId);

      final address = _web3Service.userAddress.hex;

      // Fetch balances
      final ethBalance = await _web3Service.getBalance();
      final vltcBalance = await _fetchVltcBalance();

      state = WalletState(
        address: address,
        ethBalance: ethBalance,
        vltcBalance: vltcBalance,
        isConnected: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh balances
  Future<void> refreshBalances() async {
    if (!state.isConnected) return;

    try {
      final ethBalance = await _web3Service.getBalance();
      final vltcBalance = await _fetchVltcBalance();

      state = state.copyWith(
        ethBalance: ethBalance,
        vltcBalance: vltcBalance,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Fetch VLTC token balance
  Future<BigInt> _fetchVltcBalance() async {
    try {
      // Get VaultToken address for current chain
      final addresses = ContractAddresses.getAddresses(84532); // Base Sepolia
      final vaultTokenAddress = addresses['VaultToken'];

      if (vaultTokenAddress == null || vaultTokenAddress == '0x0000000000000000000000000000000000000000') {
        return BigInt.zero;
      }

      return await _web3Service.getTokenBalance(vaultTokenAddress);
    } catch (e) {
      return BigInt.zero;
    }
  }

  /// Connect via browser wallet (MetaMask / injected provider) — web only.
  Future<void> connectWithBrowserWallet() async {
    if (!kIsWeb) {
      state = state.copyWith(
        isLoading: false,
        error: 'Browser wallet only available on web.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      if (!EthereumBridge.isAvailable) {
        throw Exception(
          'No wallet detected. Please install Base Wallet, MetaMask, or any browser wallet extension.',
        );
      }

      // 1. Connect accounts first — wallet must be authorized before chain calls.
      final address = await EthereumBridge.requestAccounts();

      // 2. Switch to Base Sepolia (after accounts are connected).
      await EthereumBridge.switchToBaseSepolia();

      // 3. Hardcode chain ID — we always target Base Sepolia (84532).
      const chainId = 84532;

      // Initialize web3 service with the connected address
      await _web3Service.initWithBrowserWallet(
        address: address,
        chainId: chainId,
      );

      await _contractService.initialize(chainId: chainId);

      final ethBalance = await _web3Service.getBalance();
      final vltcBalance = await _fetchVltcBalance();

      state = WalletState(
        address: address,
        ethBalance: ethBalance,
        vltcBalance: vltcBalance,
        isConnected: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Disconnect wallet
  void disconnect() {
    _web3Service.dispose();
    state = const WalletState();
  }
}

/// SHARED Web3Service instance - used by ALL providers
/// This ensures wallet initialization is shared across the app
final web3ServiceProvider = Provider<Web3Service>((ref) {
  return Web3Service();
});

/// SHARED ContractService instance - initialized when wallet connects
/// Also auto-initializes lazily in read-only mode when needed by browse services.
final contractServiceProvider = Provider<ContractService>((ref) {
  return ContractService();
});

/// Provider for wallet state
final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final web3Service = ref.watch(web3ServiceProvider);
  final contractService = ref.watch(contractServiceProvider);
  return WalletNotifier(web3Service, contractService);
});

/// Provider for auto-refresh (every 30 seconds)
final walletAutoRefreshProvider = StreamProvider<void>((ref) async* {
  while (true) {
    await Future.delayed(const Duration(seconds: 30));
    final walletNotifier = ref.read(walletProvider.notifier);
    await walletNotifier.refreshBalances();
    yield null;
  }
});
