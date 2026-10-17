import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';

/// VaultToken (VLTC) ERC20 Token Contract Wrapper
///
/// This class provides a type-safe interface to interact with the VaultToken
/// smart contract deployed on Base Sepolia. It handles ABI loading, function
/// encoding, and provides convenient methods for common token operations.
///
/// Contract Address (Base Sepolia): 0x9583d1643354B9C254586966343D54bCB79970D3
class VaultTokenContract {
  late DeployedContract _contract;
  late String _contractAddress;

  /// Initialize the contract with an address
  Future<void> initialize(String address) async {
    _contractAddress = address;

    // Load ABI from assets
    final abiString = await rootBundle.loadString('assets/abis/VaultToken.json');
    final abiJson = json.decode(abiString);
    final abi = abiJson['abi'] as List<dynamic>;

    _contract = DeployedContract(
      ContractAbi.fromJson(json.encode(abi), 'VaultToken'),
      EthereumAddress.fromHex(_contractAddress),
    );
  }

  /// Get the contract instance
  DeployedContract get contract => _contract;

  /// Get the contract address
  String get address => _contractAddress;

  // ============================================================================
  // VIEW FUNCTIONS (Read-only, no gas cost)
  // ============================================================================

  /// Get the balance of an address
  ///
  /// Returns the VLTC token balance for the specified address.
  /// The balance is returned in wei (1 VLTC = 10^18 wei).
  ///
  /// Example:
  /// ```dart
  /// final balance = await contract.balanceOf(userAddress);
  /// final vltc = balance / BigInt.from(10).pow(18); // Convert to VLTC
  /// ```
  ContractFunction get balanceOf => _contract.function('balanceOf');

  /// Get the total supply of VLTC tokens
  ///
  /// Returns the total amount of VLTC tokens in circulation.
  ContractFunction get totalSupply => _contract.function('totalSupply');

  /// Get the token name
  ///
  /// Returns: "VaultToken"
  ContractFunction get name => _contract.function('name');

  /// Get the token symbol
  ///
  /// Returns: "VLTC"
  ContractFunction get symbol => _contract.function('symbol');

  /// Get the number of decimals
  ///
  /// Returns: 18 (standard ERC20)
  ContractFunction get decimals => _contract.function('decimals');

  /// Get the allowance for a spender
  ///
  /// Returns how much the spender is allowed to spend on behalf of the owner.
  /// Used before calling `transferFrom`.
  ///
  /// Parameters:
  /// - owner: The address that owns the tokens
  /// - spender: The address allowed to spend the tokens
  ContractFunction get allowance => _contract.function('allowance');

  /// Get the current delegate for an address
  ///
  /// Returns the address that the given account has delegated their voting power to.
  /// Returns the zero address if not delegated.
  ///
  /// Parameters:
  /// - account: The address to check
  ///
  /// Returns: The delegate address
  ContractFunction get delegates => _contract.function('delegates');

  /// Get the voting power of an address
  ///
  /// Returns the current voting power for the given address.
  /// Voting power equals the delegated token balance.
  ///
  /// Parameters:
  /// - account: The address to check
  ///
  /// Returns: Voting power in wei
  ContractFunction get getVotes => _contract.function('getVotes');

  // ============================================================================
  // TRANSACTION FUNCTIONS (Write operations, require gas)
  // ============================================================================

  /// Transfer tokens to another address
  ///
  /// Transfers `amount` tokens from the caller's account to `recipient`.
  ///
  /// Parameters:
  /// - to: Recipient address
  /// - amount: Amount in wei (1 VLTC = 10^18 wei)
  ///
  /// Returns: Transaction object
  ///
  /// Emits: Transfer(from, to, amount)
  ///
  /// Requirements:
  /// - Caller must have balance >= amount
  /// - Recipient cannot be zero address
  ContractFunction get transfer => _contract.function('transfer');

  /// Approve a spender to use tokens
  ///
  /// Approves `spender` to spend `amount` tokens on behalf of the caller.
  /// This is typically called before purchasing content on the marketplace.
  ///
  /// Parameters:
  /// - spender: Address allowed to spend tokens (usually Marketplace contract)
  /// - amount: Amount in wei
  ///
  /// Returns: Transaction object
  ///
  /// Emits: Approval(owner, spender, amount)
  ///
  /// Example:
  /// ```dart
  /// // Approve marketplace to spend 100 VLTC
  /// final amount = BigInt.from(100) * BigInt.from(10).pow(18);
  /// final tx = await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: contract.contract,
  ///     function: contract.approve,
  ///     parameters: [marketplaceAddress, amount],
  ///   ),
  /// );
  /// ```
  ContractFunction get approve => _contract.function('approve');

  /// Transfer tokens from one address to another
  ///
  /// Used by approved spenders (like Marketplace) to transfer tokens
  /// on behalf of the owner.
  ///
  /// Parameters:
  /// - from: Address to transfer from
  /// - to: Address to transfer to
  /// - amount: Amount in wei
  ///
  /// Returns: Transaction object
  ///
  /// Requirements:
  /// - Caller must have allowance >= amount
  /// - From address must have balance >= amount
  ContractFunction get transferFrom => _contract.function('transferFrom');

  /// Delegate voting power to an address
  ///
  /// Delegates the caller's voting power to the specified address.
  /// Can delegate to self to activate own voting power.
  ///
  /// Parameters:
  /// - delegatee: Address to delegate to (use msg.sender to delegate to self)
  ///
  /// Returns: Transaction object
  ///
  /// Emits: DelegateChanged(delegator, fromDelegate, toDelegate)
  ///
  /// Example:
  /// ```dart
  /// // Delegate to self
  /// final tx = await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: contract.contract,
  ///     function: contract.delegate,
  ///     parameters: [myAddress],
  ///   ),
  /// );
  /// ```
  ContractFunction get delegate => _contract.function('delegate');

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Convert VLTC to wei
  ///
  /// Helper function to convert whole VLTC tokens to wei.
  ///
  /// Example:
  /// ```dart
  /// final wei = VaultTokenContract.vltcToWei(100); // 100 VLTC
  /// ```
  static BigInt vltcToWei(int vltc) {
    return BigInt.from(vltc) * BigInt.from(10).pow(18);
  }

  /// Convert wei to VLTC
  ///
  /// Helper function to convert wei to whole VLTC tokens.
  ///
  /// Example:
  /// ```dart
  /// final vltc = VaultTokenContract.weiToVltc(balance); // Returns double
  /// ```
  static double weiToVltc(BigInt wei) {
    return wei / BigInt.from(10).pow(18);
  }

  /// Format wei balance as string
  ///
  /// Converts wei to VLTC and formats as string with specified decimals.
  ///
  /// Example:
  /// ```dart
  /// final formatted = VaultTokenContract.formatBalance(balance, decimals: 2);
  /// // Returns: "1,234.56"
  /// ```
  static String formatBalance(BigInt wei, {int decimals = 2}) {
    final vltc = weiToVltc(wei);
    return vltc.toStringAsFixed(decimals);
  }
}
