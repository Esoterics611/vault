import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';
import '../contracts/dao_governor_contract.dart';
import '../contracts/vault_token_contract.dart';
import 'web3_service.dart';
import 'contract_service.dart';

/// Model for a DAO proposal
class Proposal {
  final BigInt proposalId;
  final String proposer;
  final List<EthereumAddress> targets;
  final List<BigInt> values;
  final List<String> signatures;
  final List<Uint8List> calldatas;
  final String description;
  final BigInt voteStart;
  final BigInt voteEnd;
  final ProposalState state;
  final BigInt forVotes;
  final BigInt againstVotes;
  final BigInt abstainVotes;

  Proposal({
    required this.proposalId,
    required this.proposer,
    required this.targets,
    required this.values,
    required this.signatures,
    required this.calldatas,
    required this.description,
    required this.voteStart,
    required this.voteEnd,
    required this.state,
    required this.forVotes,
    required this.againstVotes,
    required this.abstainVotes,
  });

  bool get isActive => state == ProposalState.active;
  bool get hasSucceeded => state == ProposalState.succeeded;
  bool get isQueued => state == ProposalState.queued;
  bool get isExecuted => state == ProposalState.executed;
  bool get canVote => state == ProposalState.active;
  bool get canQueue => state == ProposalState.succeeded;
  bool get canExecute => state == ProposalState.queued;

  double get totalVotes {
    final total = forVotes + againstVotes + abstainVotes;
    return total > BigInt.zero ? total.toDouble() / 1e18 : 0.0;
  }

  double get forPercentage {
    if (totalVotes == 0) return 0.0;
    return (forVotes.toDouble() / 1e18) / totalVotes * 100;
  }

  double get againstPercentage {
    if (totalVotes == 0) return 0.0;
    return (againstVotes.toDouble() / 1e18) / totalVotes * 100;
  }

  double get abstainPercentage {
    if (totalVotes == 0) return 0.0;
    return (abstainVotes.toDouble() / 1e18) / totalVotes * 100;
  }
}

/// Enum for proposal types
enum ProposalType {
  feeChange,
  treasuryAction,
  pauseContract,
  custom,
}

/// Service for interacting with DAO governance
class GovernanceService {
  final Web3Service _web3Service;
  final ContractService _contractService;

  GovernanceService(this._web3Service, this._contractService);

  DAOGovernorContract get _governor => _contractService.daoGovernor;
  VaultTokenContract get _token => _contractService.vaultToken;

  /// Get voting power for an address at current block
  Future<BigInt> getVotingPower(String address) async {
    try {
      final result = await _web3Service.call(
        contract: _governor.contract,
        function: _governor.getVotes,
        params: [EthereumAddress.fromHex(address)],
      );

      return result[0] as BigInt;
    } catch (e) {
      print('Error getting voting power: $e');
      return BigInt.zero;
    }
  }

  /// Get token balance for an address
  Future<BigInt> getTokenBalance(String address) async {
    try {
      final result = await _web3Service.call(
        contract: _token.contract,
        function: _token.balanceOf,
        params: [EthereumAddress.fromHex(address)],
      );

      return result[0] as BigInt;
    } catch (e) {
      print('Error getting token balance: $e');
      return BigInt.zero;
    }
  }

  /// Delegate voting power to another address
  Future<String> delegateVotes(String delegatee) async {
    try {
      final txHash = await _web3Service.sendContract(
        contract: _token.contract,
        function: _token.delegate,
        parameters: [EthereumAddress.fromHex(delegatee)],
      );

      print('Delegation transaction sent: $txHash');
      await _web3Service.waitForReceipt(txHash);
      print('Delegation confirmed');

      return txHash;
    } catch (e) {
      print('Error delegating votes: $e');
      rethrow;
    }
  }

  /// Get current delegate for an address
  Future<String> getCurrentDelegate(String address) async {
    try {
      final result = await _web3Service.call(
        contract: _token.contract,
        function: _token.delegates,
        params: [EthereumAddress.fromHex(address)],
      );

      final delegate = result[0] as EthereumAddress;
      return delegate.hexEip55;
    } catch (e) {
      print('Error getting delegate: $e');
      return '0x0000000000000000000000000000000000000000';
    }
  }

  /// Get governance parameters
  Future<Map<String, BigInt>> getGovernanceParams() async {
    try {
      final votingDelayResult = await _web3Service.call(
        contract: _governor.contract,
        function: _governor.votingDelay,
        params: [],
      );

      final votingPeriodResult = await _web3Service.call(
        contract: _governor.contract,
        function: _governor.votingPeriod,
        params: [],
      );

      final proposalThresholdResult = await _web3Service.call(
        contract: _governor.contract,
        function: _governor.proposalThreshold,
        params: [],
      );

      final currentBlock = await _web3Service.client.getBlockNumber();
      final quorumResult = await _web3Service.call(
        contract: _governor.contract,
        function: _governor.quorum,
        params: [BigInt.from(currentBlock)],
      );

      return {
        'votingDelay': votingDelayResult[0] as BigInt,
        'votingPeriod': votingPeriodResult[0] as BigInt,
        'proposalThreshold': proposalThresholdResult[0] as BigInt,
        'quorum': quorumResult[0] as BigInt,
      };
    } catch (e) {
      print('Error getting governance params: $e');
      return {
        'votingDelay': BigInt.zero,
        'votingPeriod': BigInt.zero,
        'proposalThreshold': BigInt.zero,
        'quorum': BigInt.zero,
      };
    }
  }

  /// Create a proposal
  Future<BigInt> createProposal({
    required List<EthereumAddress> targets,
    required List<BigInt> values,
    required List<Uint8List> calldatas,
    required String description,
  }) async {
    try {
      print('Creating proposal: $description');

      // Generate proposal ID
      final descriptionHash = keccak256(Uint8List.fromList(description.codeUnits));
      final proposalId = _hashProposal(targets, values, calldatas, descriptionHash);

      print('Calculated proposal ID: $proposalId');

      // Submit proposal transaction
      final txHash = await _web3Service.sendContract(
        contract: _governor.contract,
        function: _governor.propose,
        parameters: [
          targets,
          values,
          calldatas,
          description,
        ],
      );

      print('Proposal transaction sent: $txHash');
      await _web3Service.waitForReceipt(txHash);
      print('Proposal created with ID: $proposalId');

      return proposalId;
    } catch (e) {
      print('Error creating proposal: $e');
      rethrow;
    }
  }

  /// Hash proposal to get proposal ID (matches Solidity implementation)
  BigInt _hashProposal(
    List<EthereumAddress> targets,
    List<BigInt> values,
    List<Uint8List> calldatas,
    Uint8List descriptionHash,
  ) {
    // This matches the OpenZeppelin Governor hashProposal implementation
    final targetsEncoded = targets.map((t) => t.addressBytes).toList();
    final valuesEncoded = values.map((v) => encodeBigInt(v)).toList();

    final encoded = encodePacked([
      ...targetsEncoded,
      ...valuesEncoded,
      ...calldatas,
      descriptionHash,
    ]);

    final hash = keccak256(encoded);
    return bytesToUint(hash);
  }

  /// Get proposal state
  Future<ProposalState> getProposalState(BigInt proposalId) async {
    try {
      final result = await _web3Service.call(
        contract: _governor.contract,
        function: _governor.state,
        params: [proposalId],
      );

      final stateValue = (result[0] as BigInt).toInt();
      return ProposalState.values.firstWhere(
        (s) => s.value == stateValue,
        orElse: () => ProposalState.pending,
      );
    } catch (e) {
      print('Error getting proposal state: $e');
      return ProposalState.pending;
    }
  }

  /// Get proposal votes
  Future<Map<String, BigInt>> getProposalVotes(BigInt proposalId) async {
    try {
      final result = await _web3Service.call(
        contract: _governor.contract,
        function: _governor.proposalVotes,
        params: [proposalId],
      );

      return {
        'against': result[0] as BigInt,
        'for': result[1] as BigInt,
        'abstain': result[2] as BigInt,
      };
    } catch (e) {
      print('Error getting proposal votes: $e');
      return {
        'against': BigInt.zero,
        'for': BigInt.zero,
        'abstain': BigInt.zero,
      };
    }
  }

  /// Get proposal snapshot (block number when voting starts)
  Future<BigInt> getProposalSnapshot(BigInt proposalId) async {
    try {
      final result = await _web3Service.call(
        contract: _governor.contract,
        function: _governor.proposalSnapshot,
        params: [proposalId],
      );

      return result[0] as BigInt;
    } catch (e) {
      print('Error getting proposal snapshot: $e');
      return BigInt.zero;
    }
  }

  /// Get proposal deadline (block number when voting ends)
  Future<BigInt> getProposalDeadline(BigInt proposalId) async {
    try {
      final result = await _web3Service.call(
        contract: _governor.contract,
        function: _governor.proposalDeadline,
        params: [proposalId],
      );

      return result[0] as BigInt;
    } catch (e) {
      print('Error getting proposal deadline: $e');
      return BigInt.zero;
    }
  }

  /// Check if address has voted on proposal
  Future<bool> hasVoted(BigInt proposalId, String voterAddress) async {
    try {
      final result = await _web3Service.call(
        contract: _governor.contract,
        function: _governor.hasVoted,
        params: [proposalId, EthereumAddress.fromHex(voterAddress)],
      );

      return result[0] as bool;
    } catch (e) {
      print('Error checking has voted: $e');
      return false;
    }
  }

  /// Cast a vote on a proposal
  Future<String> castVote({
    required BigInt proposalId,
    required VoteSupport support,
    String? reason,
  }) async {
    try {
      print('Casting vote on proposal $proposalId with support: ${support.name}');

      final String txHash;

      if (reason != null && reason.isNotEmpty) {
        txHash = await _web3Service.sendContract(
          contract: _governor.contract,
          function: _governor.castVoteWithReason,
          parameters: [proposalId, BigInt.from(support.value), reason],
        );
      } else {
        txHash = await _web3Service.sendContract(
          contract: _governor.contract,
          function: _governor.castVote,
          parameters: [proposalId, BigInt.from(support.value)],
        );
      }

      print('Vote transaction sent: $txHash');
      await _web3Service.waitForReceipt(txHash);
      print('Vote confirmed');

      return txHash;
    } catch (e) {
      print('Error casting vote: $e');
      rethrow;
    }
  }

  /// Queue a succeeded proposal
  Future<String> queueProposal({
    required BigInt proposalId,
    required List<EthereumAddress> targets,
    required List<BigInt> values,
    required List<Uint8List> calldatas,
    required String description,
  }) async {
    try {
      print('Queueing proposal: $proposalId');

      final descriptionHash = keccak256(Uint8List.fromList(description.codeUnits));

      final txHash = await _web3Service.sendContract(
        contract: _governor.contract,
        function: _governor.queue,
        parameters: [targets, values, calldatas, descriptionHash],
      );

      print('Queue transaction sent: $txHash');
      await _web3Service.waitForReceipt(txHash);
      print('Proposal queued');

      return txHash;
    } catch (e) {
      print('Error queueing proposal: $e');
      rethrow;
    }
  }

  /// Execute a queued proposal
  Future<String> executeProposal({
    required BigInt proposalId,
    required List<EthereumAddress> targets,
    required List<BigInt> values,
    required List<Uint8List> calldatas,
    required String description,
  }) async {
    try {
      print('Executing proposal: $proposalId');

      final descriptionHash = keccak256(Uint8List.fromList(description.codeUnits));

      final txHash = await _web3Service.sendContract(
        contract: _governor.contract,
        function: _governor.execute,
        parameters: [targets, values, calldatas, descriptionHash],
      );

      print('Execute transaction sent: $txHash');
      await _web3Service.waitForReceipt(txHash);
      print('Proposal executed');

      return txHash;
    } catch (e) {
      print('Error executing proposal: $e');
      rethrow;
    }
  }

  /// Cancel a proposal
  Future<String> cancelProposal({
    required BigInt proposalId,
    required List<EthereumAddress> targets,
    required List<BigInt> values,
    required List<Uint8List> calldatas,
    required String description,
  }) async {
    try {
      print('Canceling proposal: $proposalId');

      final descriptionHash = keccak256(Uint8List.fromList(description.codeUnits));

      final txHash = await _web3Service.sendContract(
        contract: _governor.contract,
        function: _governor.cancel,
        parameters: [targets, values, calldatas, descriptionHash],
      );

      print('Cancel transaction sent: $txHash');
      await _web3Service.waitForReceipt(txHash);
      print('Proposal canceled');

      return txHash;
    } catch (e) {
      print('Error canceling proposal: $e');
      rethrow;
    }
  }

  /// Helper to encode BigInt for hashing
  Uint8List encodeBigInt(BigInt value) {
    final bytes = Uint8List(32);
    var tempValue = value;
    for (int i = 31; i >= 0; i--) {
      bytes[i] = (tempValue & BigInt.from(0xff)).toInt();
      tempValue = tempValue >> 8;
    }
    return bytes;
  }

  /// Helper to encode packed bytes
  Uint8List encodePacked(List<dynamic> values) {
    final List<int> result = [];
    for (final value in values) {
      if (value is Uint8List) {
        result.addAll(value);
      } else if (value is List<int>) {
        result.addAll(value);
      }
    }
    return Uint8List.fromList(result);
  }

  /// Helper to convert bytes to uint
  BigInt bytesToUint(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (int i = 0; i < bytes.length; i++) {
      result = (result << 8) + BigInt.from(bytes[i]);
    }
    return result;
  }

  /// Helper to create calldata for marketplace fee change
  Uint8List createSetPlatformFeeCalldata(BigInt newFee) {
    // Function selector for setPlatformFee(uint256)
    final selector = keccak256(Uint8List.fromList('setPlatformFee(uint256)'.codeUnits)).sublist(0, 4);
    final encodedFee = encodeBigInt(newFee);
    return Uint8List.fromList([...selector, ...encodedFee]);
  }

  /// Helper to create calldata for pausing contract
  Uint8List createPauseCalldata() {
    // Function selector for pause()
    final selector = keccak256(Uint8List.fromList('pause()'.codeUnits)).sublist(0, 4);
    return selector;
  }

  /// Helper to create calldata for unpausing contract
  Uint8List createUnpauseCalldata() {
    // Function selector for unpause()
    final selector = keccak256(Uint8List.fromList('unpause()'.codeUnits)).sublist(0, 4);
    return selector;
  }
}
