import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';

/// Proposal State Enum
///
/// Matches the ProposalState enum in OpenZeppelin Governor
enum ProposalState {
  pending(0),     // Voting hasn't started yet (voting delay)
  active(1),      // Voting in progress
  canceled(2),    // Proposal was canceled
  defeated(3),    // Voting failed or quorum not reached
  succeeded(4),   // Voting passed, ready to queue
  queued(5),      // In timelock, waiting for execution
  expired(6),     // Timelock expired without execution
  executed(7);    // Proposal successfully executed

  const ProposalState(this.value);
  final int value;

  String get displayName {
    switch (this) {
      case ProposalState.pending:
        return 'Pending';
      case ProposalState.active:
        return 'Active';
      case ProposalState.canceled:
        return 'Canceled';
      case ProposalState.defeated:
        return 'Defeated';
      case ProposalState.succeeded:
        return 'Succeeded';
      case ProposalState.queued:
        return 'Queued';
      case ProposalState.expired:
        return 'Expired';
      case ProposalState.executed:
        return 'Executed';
    }
  }
}

/// Vote Support Enum
///
/// Support values for casting votes
enum VoteSupport {
  against(0),   // Vote against the proposal
  for_(1),      // Vote for the proposal
  abstain(2);   // Abstain from voting (counts toward quorum)

  const VoteSupport(this.value);
  final int value;
}

/// DAOGovernor Smart Contract Wrapper
///
/// This class provides a type-safe interface to interact with the DAOGovernor
/// smart contract based on OpenZeppelin's Governor.
///
/// Contract Address (Base Sepolia): 0xc0cE9E7376c401FB74264D0312afc7d91B191050
///
/// Governance Parameters:
/// - Voting Delay: 1 day (86,400 seconds)
/// - Voting Period: 7 days (604,800 seconds)
/// - Proposal Threshold: 100,000 VLTC
/// - Quorum: 4% of total supply (40,000,000 VLTC)
/// - Timelock Delay: 48 hours (172,800 seconds)
class DAOGovernorContract {
  late DeployedContract _contract;
  late String _contractAddress;

  /// Initialize the contract with an address
  Future<void> initialize(String address) async {
    _contractAddress = address;

    // Load ABI from assets
    final abiString = await rootBundle.loadString('assets/abis/DAOGovernor.json');
    final abiJson = json.decode(abiString);
    final abi = abiJson['abi'] as List<dynamic>;

    _contract = DeployedContract(
      ContractAbi.fromJson(json.encode(abi), 'DAOGovernor'),
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

  /// Get proposal state
  ///
  /// Returns the current state of a proposal.
  ///
  /// Parameters:
  /// - proposalId: The ID of the proposal
  ///
  /// Returns: ProposalState enum value
  ContractFunction get state => _contract.function('state');

  /// Get proposal votes
  ///
  /// Returns the vote counts for a proposal.
  ///
  /// Parameters:
  /// - proposalId: The ID of the proposal
  ///
  /// Returns tuple: (againstVotes, forVotes, abstainVotes)
  ContractFunction get proposalVotes => _contract.function('proposalVotes');

  /// Check if user has voted
  ///
  /// Parameters:
  /// - proposalId: The ID of the proposal
  /// - account: The address to check
  ///
  /// Returns: bool (true if voted)
  ContractFunction get hasVoted => _contract.function('hasVoted');

  /// Get voting power
  ///
  /// Get the voting power of an account at a specific block number.
  ///
  /// Parameters:
  /// - account: The address to check
  /// - timepoint: The block number to check at
  ///
  /// Returns: uint256 voting power
  ContractFunction get getVotes => _contract.function('getVotes');

  /// Get quorum requirement
  ///
  /// Get the minimum votes required for a proposal to pass at a block number.
  ///
  /// Parameters:
  /// - timepoint: The block number
  ///
  /// Returns: uint256 quorum amount
  ContractFunction get quorum => _contract.function('quorum');

  /// Get voting delay
  ///
  /// Returns the delay between proposal creation and voting start (in blocks).
  ContractFunction get votingDelay => _contract.function('votingDelay');

  /// Get voting period
  ///
  /// Returns the duration of voting period (in blocks).
  ContractFunction get votingPeriod => _contract.function('votingPeriod');

  /// Get proposal threshold
  ///
  /// Returns the minimum voting power required to create a proposal.
  ContractFunction get proposalThreshold => _contract.function('proposalThreshold');

  /// Get proposal snapshot
  ///
  /// Returns the block number at which voting power is measured for this proposal.
  ///
  /// Parameters:
  /// - proposalId: The ID of the proposal
  ///
  /// Returns: uint256 block number
  ContractFunction get proposalSnapshot => _contract.function('proposalSnapshot');

  /// Get proposal deadline
  ///
  /// Returns the block number when voting ends for this proposal.
  ///
  /// Parameters:
  /// - proposalId: The ID of the proposal
  ///
  /// Returns: uint256 block number
  ContractFunction get proposalDeadline => _contract.function('proposalDeadline');

  /// Get proposal ETA
  ///
  /// Returns the execution timestamp for a queued proposal.
  ///
  /// Parameters:
  /// - proposalId: The ID of the proposal
  ///
  /// Returns: uint256 timestamp
  ContractFunction get proposalEta => _contract.function('proposalEta');

  /// Check if proposal needs queuing
  ///
  /// Parameters:
  /// - proposalId: The ID of the proposal
  ///
  /// Returns: bool
  ContractFunction get proposalNeedsQueuing => _contract.function('proposalNeedsQueuing');

  // ============================================================================
  // TRANSACTION FUNCTIONS (Write operations, require gas)
  // ============================================================================

  /// Create a new proposal
  ///
  /// Parameters:
  /// - targets: Array of addresses to call
  /// - values: Array of ETH amounts to send (usually all 0)
  /// - calldatas: Array of encoded function calls
  /// - description: Human-readable description
  ///
  /// Returns: uint256 proposalId
  ///
  /// Requirements:
  /// - Caller must have >= proposal threshold voting power
  /// - Caller must have delegated votes to themselves
  ///
  /// Example:
  /// ```dart
  /// final targets = [marketplaceAddress];
  /// final values = [BigInt.zero];
  /// final calldatas = [encodedSetFeeCall];
  /// final description = "Proposal to change platform fee to 3%";
  ///
  /// final txHash = await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: daoGovernor.contract,
  ///     function: daoGovernor.propose,
  ///     parameters: [targets, values, calldatas, description],
  ///   ),
  /// );
  /// ```
  ContractFunction get propose => _contract.function('propose');

  /// Cast a vote
  ///
  /// Parameters:
  /// - proposalId: The ID of the proposal
  /// - support: 0 = Against, 1 = For, 2 = Abstain
  ///
  /// Returns: uint256 vote weight
  ///
  /// Requirements:
  /// - Proposal must be in Active state
  /// - Caller must not have already voted
  /// - Caller must have voting power at snapshot block
  ///
  /// Example:
  /// ```dart
  /// await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: daoGovernor.contract,
  ///     function: daoGovernor.castVote,
  ///     parameters: [proposalId, BigInt.from(VoteSupport.for_.value)],
  ///   ),
  /// );
  /// ```
  ContractFunction get castVote => _contract.function('castVote');

  /// Cast a vote with reason
  ///
  /// Parameters:
  /// - proposalId: The ID of the proposal
  /// - support: 0 = Against, 1 = For, 2 = Abstain
  /// - reason: String explanation of vote
  ///
  /// Returns: uint256 vote weight
  ///
  /// Example:
  /// ```dart
  /// await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: daoGovernor.contract,
  ///     function: daoGovernor.castVoteWithReason,
  ///     parameters: [
  ///       proposalId,
  ///       BigInt.from(VoteSupport.for_.value),
  ///       "I support this proposal because...",
  ///     ],
  ///   ),
  /// );
  /// ```
  ContractFunction get castVoteWithReason => _contract.function('castVoteWithReason');

  /// Queue a succeeded proposal
  ///
  /// Parameters:
  /// - targets: Array of addresses (same as propose)
  /// - values: Array of values (same as propose)
  /// - calldatas: Array of calldatas (same as propose)
  /// - descriptionHash: keccak256 hash of description
  ///
  /// Returns: uint256 proposalId
  ///
  /// Requirements:
  /// - Proposal must be in Succeeded state
  /// - Timelock delay will start (48 hours)
  ///
  /// Example:
  /// ```dart
  /// final descriptionHash = keccak256(utf8.encode(description));
  /// await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: daoGovernor.contract,
  ///     function: daoGovernor.queue,
  ///     parameters: [targets, values, calldatas, descriptionHash],
  ///   ),
  /// );
  /// ```
  ContractFunction get queue => _contract.function('queue');

  /// Execute a queued proposal
  ///
  /// Parameters:
  /// - targets: Array of addresses (same as propose)
  /// - values: Array of values (same as propose)
  /// - calldatas: Array of calldatas (same as propose)
  /// - descriptionHash: keccak256 hash of description
  ///
  /// Returns: uint256 proposalId
  ///
  /// Requirements:
  /// - Proposal must be in Queued state
  /// - Timelock delay must have passed (48 hours)
  /// - Anyone can execute (doesn't need to be proposer)
  ///
  /// Example:
  /// ```dart
  /// final descriptionHash = keccak256(utf8.encode(description));
  /// await web3.sendTransaction(
  ///   credentials,
  ///   Transaction.callContract(
  ///     contract: daoGovernor.contract,
  ///     function: daoGovernor.execute,
  ///     parameters: [targets, values, calldatas, descriptionHash],
  ///   ),
  ///   chainId: 84532,
  /// );
  /// ```
  ContractFunction get execute => _contract.function('execute');

  /// Cancel a proposal
  ///
  /// Parameters:
  /// - targets: Array of addresses (same as propose)
  /// - values: Array of values (same as propose)
  /// - calldatas: Array of calldatas (same as propose)
  /// - descriptionHash: keccak256 hash of description
  ///
  /// Returns: uint256 proposalId
  ///
  /// Requirements:
  /// - Caller must be proposer OR proposer's voting power dropped below threshold
  ContractFunction get cancel => _contract.function('cancel');

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Calculate proposal ID
  ///
  /// Generates the proposal ID from its parameters (same as on-chain calculation).
  ///
  /// The proposal ID is the keccak256 hash of:
  /// - targets (address[])
  /// - values (uint256[])
  /// - calldatas (bytes[])
  /// - descriptionHash (bytes32)
  static Uint8List calculateProposalId(
    List<EthereumAddress> targets,
    List<BigInt> values,
    List<Uint8List> calldatas,
    Uint8List descriptionHash,
  ) {
    // This would require proper ABI encoding
    // For now, return placeholder - implement with proper keccak256
    return Uint8List(32);
  }

  /// Parse vote counts from proposalVotes result
  static Map<String, BigInt> parseVoteCounts(List<dynamic> result) {
    return {
      'against': result[0] as BigInt,
      'for': result[1] as BigInt,
      'abstain': result[2] as BigInt,
    };
  }

  /// Get proposal state from integer
  static ProposalState getProposalStateFromInt(int stateValue) {
    return ProposalState.values.firstWhere(
      (e) => e.value == stateValue,
      orElse: () => ProposalState.pending,
    );
  }

  /// Format voting power
  static String formatVotingPower(BigInt votingPower) {
    final vltc = votingPower / BigInt.from(10).pow(18);
    if (vltc >= 1000000) {
      return '${(vltc / 1000000).toStringAsFixed(2)}M VLTC';
    } else if (vltc >= 1000) {
      return '${(vltc / 1000).toStringAsFixed(2)}K VLTC';
    } else {
      return '${vltc.toStringAsFixed(2)} VLTC';
    }
  }

  /// Check if voting power meets threshold
  static bool meetsProposalThreshold(BigInt votingPower, BigInt threshold) {
    return votingPower >= threshold;
  }

  /// Check if quorum is met
  static bool meetsQuorum(BigInt totalVotes, BigInt quorumRequired) {
    return totalVotes >= quorumRequired;
  }
}
