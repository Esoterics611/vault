import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import '../contracts/marketplace_contract.dart';
import '../contracts/vault_token_contract.dart';
import '../services/web3_service.dart';
import '../services/contract_service.dart';

/// Purchase Result
///
/// Contains information about a completed purchase transaction.
class PurchaseResult {
  final String transactionHash;
  final BigInt contentId;
  final BigInt listingId;
  final BigInt price;
  final String reEncryptedKey;
  final DateTime purchaseTime;

  PurchaseResult({
    required this.transactionHash,
    required this.contentId,
    required this.listingId,
    required this.price,
    required this.reEncryptedKey,
    required this.purchaseTime,
  });

  Map<String, dynamic> toJson() => {
        'transactionHash': transactionHash,
        'contentId': contentId.toString(),
        'listingId': listingId.toString(),
        'price': price.toString(),
        'reEncryptedKey': reEncryptedKey,
        'purchaseTime': purchaseTime.toIso8601String(),
      };

  factory PurchaseResult.fromJson(Map<String, dynamic> json) => PurchaseResult(
        transactionHash: json['transactionHash'],
        contentId: BigInt.parse(json['contentId']),
        listingId: BigInt.parse(json['listingId']),
        price: BigInt.parse(json['price']),
        reEncryptedKey: json['reEncryptedKey'],
        purchaseTime: DateTime.parse(json['purchaseTime']),
      );
}

/// Purchase Step Enum
///
/// Tracks the current step in the purchase flow.
enum PurchaseStep {
  checking,
  approvingToken,
  purchasing,
  requestingKey,
  complete,
}

/// Content Purchase Service
///
/// Handles the complete purchase flow including:
/// - VLTC token approval
/// - Marketplace purchase transaction
/// - PRE re-encryption key request
/// - Local storage of purchased content keys
class ContentPurchaseService {
  final Web3Service web3Service;
  final ContractService contractService;
  final String preProxyUrl;

  ContentPurchaseService({
    required this.web3Service,
    required this.contractService,
    this.preProxyUrl = 'http://10.0.0.2:3001', // Production-ready host IP
  });

  /// Check if user has sufficient VLTC balance
  ///
  /// Parameters:
  /// - userAddress: The buyer's wallet address
  /// - price: Required price in wei
  ///
  /// Returns true if balance is sufficient.
  Future<bool> checkBalance({
    required String userAddress,
    required BigInt price,
  }) async {
    try {
      final result = await web3Service.call(
        contract: contractService.vaultToken.contract,
        function: contractService.vaultToken.balanceOf,
        params: [EthereumAddress.fromHex(userAddress)],
      );

      final balance = result[0] as BigInt;
      return balance >= price;
    } catch (e) {
      throw Exception('Failed to check balance: $e');
    }
  }

  /// Check if Marketplace has sufficient allowance
  ///
  /// Parameters:
  /// - userAddress: The buyer's wallet address
  /// - price: Required price in wei
  ///
  /// Returns true if allowance is sufficient.
  Future<bool> checkAllowance({
    required String userAddress,
    required BigInt price,
  }) async {
    try {
      final marketplaceAddress = contractService.marketplace.address;

      final result = await web3Service.call(
        contract: contractService.vaultToken.contract,
        function: contractService.vaultToken.allowance,
        params: [
          EthereumAddress.fromHex(userAddress),
          EthereumAddress.fromHex(marketplaceAddress),
        ],
      );

      final allowance = result[0] as BigInt;
      return allowance >= price;
    } catch (e) {
      throw Exception('Failed to check allowance: $e');
    }
  }

  /// Approve VLTC tokens for Marketplace
  ///
  /// Parameters:
  /// - amount: Amount to approve in wei (use max uint256 for unlimited)
  ///
  /// Returns transaction hash.
  Future<String> approveTokens({
    required BigInt amount,
  }) async {
    try {
      final marketplaceAddress = contractService.marketplace.address;

      final txHash = await web3Service.sendContract(
        contract: contractService.vaultToken.contract,
        function: contractService.vaultToken.approve,
        parameters: [
          EthereumAddress.fromHex(marketplaceAddress),
          amount,
        ],
      );

      // Wait for confirmation
      final receipt = await web3Service.waitForReceipt(txHash);
      if (receipt == null || !receipt.status!) {
        throw Exception('Token approval transaction failed');
      }

      return txHash;
    } catch (e) {
      throw Exception('Failed to approve tokens: $e');
    }
  }

  /// Purchase content from marketplace
  ///
  /// This is the main purchase method that orchestrates the complete flow:
  /// 1. Check balance
  /// 2. Check/request allowance
  /// 3. Execute purchase transaction
  /// 4. Request re-encryption key
  /// 5. Return purchase result
  ///
  /// Parameters:
  /// - listingId: The marketplace listing ID
  /// - buyerAddress: The buyer's wallet address
  /// - onProgress: Optional callback for progress updates
  ///
  /// Returns PurchaseResult with transaction details and re-encrypted key.
  Future<PurchaseResult> purchaseContent({
    required BigInt listingId,
    required String buyerAddress,
    Function(PurchaseStep step, double progress)? onProgress,
  }) async {
    try {
      // Step 1: Get listing details
      onProgress?.call(PurchaseStep.checking, 0.1);

      final listing = await _getListingDetails(listingId);
      final contentId = listing['contentId'] as BigInt;
      final price = listing['price'] as BigInt;
      final seller = listing['seller'] as String;

      // Validate listing
      if (!(listing['isActive'] as bool)) {
        throw Exception('Listing is not active');
      }

      if (seller.toLowerCase() == buyerAddress.toLowerCase()) {
        throw Exception('Cannot purchase your own content');
      }

      // Step 2: Check balance
      onProgress?.call(PurchaseStep.checking, 0.2);

      final hasBalance = await checkBalance(
        userAddress: buyerAddress,
        price: price,
      );

      if (!hasBalance) {
        throw Exception('Insufficient VLTC balance');
      }

      // Step 3: Check allowance
      onProgress?.call(PurchaseStep.checking, 0.3);

      final hasAllowance = await checkAllowance(
        userAddress: buyerAddress,
        price: price,
      );

      // Step 4: Approve if needed
      if (!hasAllowance) {
        onProgress?.call(PurchaseStep.approvingToken, 0.4);

        // Approve exact amount + 10% buffer
        final approveAmount = price * BigInt.from(110) ~/ BigInt.from(100);

        await approveTokens(amount: approveAmount);

        onProgress?.call(PurchaseStep.approvingToken, 0.5);
      } else {
        onProgress?.call(PurchaseStep.approvingToken, 0.5);
      }

      // Step 5: Execute purchase
      onProgress?.call(PurchaseStep.purchasing, 0.6);

      final txHash = await _executePurchase(listingId);

      onProgress?.call(PurchaseStep.purchasing, 0.7);

      // Wait for confirmation
      final receipt = await web3Service.waitForReceipt(txHash);
      if (receipt == null || !receipt.status!) {
        throw Exception('Purchase transaction failed');
      }

      onProgress?.call(PurchaseStep.purchasing, 0.8);

      // Step 6: Request re-encryption key
      onProgress?.call(PurchaseStep.requestingKey, 0.85);

      final reEncryptedKey = await _requestReEncryptionKey(
        contentId: contentId,
        buyerAddress: buyerAddress,
      );

      onProgress?.call(PurchaseStep.requestingKey, 0.95);

      // Step 7: Create result
      final result = PurchaseResult(
        transactionHash: txHash,
        contentId: contentId,
        listingId: listingId,
        price: price,
        reEncryptedKey: reEncryptedKey,
        purchaseTime: DateTime.now(),
      );

      onProgress?.call(PurchaseStep.complete, 1.0);

      return result;
    } catch (e) {
      throw Exception('Purchase failed: $e');
    }
  }

  /// Get listing details from Marketplace contract
  Future<Map<String, dynamic>> _getListingDetails(BigInt listingId) async {
    try {
      final result = await web3Service.call(
        contract: contractService.marketplace.contract,
        function: contractService.marketplace.listings,
        params: [listingId],
      );

      return {
        'listingId': listingId,
        'seller': result[0].toString(),
        'contentId': result[1] as BigInt,
        'price': result[2] as BigInt,
        'listingType': result[3] as BigInt,
        'accessDuration': result[4] as BigInt,
        'maxKeys': result[5] as BigInt,
        'keysIssued': result[6] as BigInt,
        'isActive': result[7] as bool,
        'createdAt': result[8] as BigInt,
      };
    } catch (e) {
      throw Exception('Failed to get listing details: $e');
    }
  }

  /// Execute purchase transaction on Marketplace
  Future<String> _executePurchase(BigInt listingId) async {
    try {
      final txHash = await web3Service.sendContract(
        contract: contractService.marketplace.contract,
        function: contractService.marketplace.purchaseListing,
        parameters: [listingId],
      );

      return txHash;
    } catch (e) {
      throw Exception('Failed to execute purchase: $e');
    }
  }

  /// Request re-encryption key from PRE Proxy
  ///
  /// Parameters:
  /// - contentId: The content ID
  /// - buyerAddress: The buyer's wallet address
  ///
  /// Returns the re-encrypted key (hex string).
  Future<String> _requestReEncryptionKey({
    required BigInt contentId,
    required String buyerAddress,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$preProxyUrl/api/proxy/re-encrypt'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contentId': contentId.toString(),
          'buyerAddress': buyerAddress,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['reEncryptedKey'] as String;
      } else {
        throw Exception(
            'PRE re-encryption failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to request re-encryption key: $e');
    }
  }

  /// Check if user owns content
  ///
  /// Parameters:
  /// - contentId: The content ID
  /// - userAddress: The user's wallet address
  ///
  /// Returns true if user is owner or has purchased.
  Future<bool> checkOwnership({
    required BigInt contentId,
    required String userAddress,
  }) async {
    try {
      // Get content owner from ContentRegistry
      final contentResult = await web3Service.call(
        contract: contractService.contentRegistry.contract,
        function: contractService.contentRegistry.getContent,
        params: [contentId],
      );

      final owner = contentResult[0].toString().toLowerCase();
      final userAddr = userAddress.toLowerCase();

      // Check if user is the original owner
      if (owner == userAddr) {
        return true;
      }

      // Check if user has purchased from Marketplace
      // This would require checking purchase history or license NFTs
      // For now, we'll implement a simpler version
      // TODO: Implement comprehensive ownership check

      return false;
    } catch (e) {
      throw Exception('Failed to check ownership: $e');
    }
  }

  /// Get user's purchase history
  ///
  /// This requires indexing purchase events from the blockchain.
  /// For now, returns empty list.
  /// TODO: Implement with event indexing or backend API.
  Future<List<PurchaseResult>> getPurchaseHistory(String userAddress) async {
    // TODO: Implement with backend API or event indexing
    return [];
  }

  /// Calculate total price including fees
  ///
  /// Parameters:
  /// - basePrice: Base content price in wei
  ///
  /// Returns total price with marketplace fees.
  BigInt calculateTotalPrice(BigInt basePrice) {
    // Marketplace typically takes 2-5% fee
    // For now, return base price (fees handled in contract)
    return basePrice;
  }

  /// Format price for display
  ///
  /// Parameters:
  /// - priceWei: Price in wei
  ///
  /// Returns formatted string like "10 VLTC".
  String formatPrice(BigInt priceWei) {
    // Convert from wei to VLTC (18 decimals)
    final vltc = priceWei ~/ BigInt.from(10).pow(18);
    final remainder = priceWei % BigInt.from(10).pow(18);

    if (remainder == BigInt.zero) {
      return '$vltc VLTC';
    }

    // Show up to 4 decimal places
    final decimals = remainder ~/ BigInt.from(10).pow(14);
    final decimalStr = decimals.toString().padLeft(4, '0');
    return '$vltc.$decimalStr VLTC';
  }
}
