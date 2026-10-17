import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:web3dart/web3dart.dart';
import '../constants/api_endpoints.dart';
import 'web3_service.dart';

/// Proposal Status Enum
enum ProposalStatus {
  pending(0),    // Awaiting start
  active(1),     // Voting open
  canceled(2),   // Canceled by proposer
  defeated(3),   // Not enough votes
  succeeded(4),  // Passed
  queued(5),     // In timelock
  expired(6),    // Expired
  executed(7);   // Executed

  const ProposalStatus(this.value);
  final int value;

  static ProposalStatus fromValue(int value) {
    return ProposalStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ProposalStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case ProposalStatus.pending:
        return 'Pending';
      case ProposalStatus.active:
        return 'Active';
      case ProposalStatus.canceled:
        return 'Canceled';
      case ProposalStatus.defeated:
        return 'Defeated';
      case ProposalStatus.succeeded:
        return 'Succeeded';
      case ProposalStatus.queued:
        return 'Queued';
      case ProposalStatus.expired:
        return 'Expired';
      case ProposalStatus.executed:
        return 'Executed';
    }
  }

  bool get isActive => this == ProposalStatus.active;
  bool get canVote => this == ProposalStatus.active;
}

/// DAO Proposal Model
class DAOProposal {
  final String id;
  final String proposalId; // On-chain proposal ID
  final String title;
  final String description;
  final EthereumAddress proposer;
  final ProposalStatus status;
  final BigInt forVotes;
  final BigInt againstVotes;
  final BigInt abstainVotes;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdAt;

  DAOProposal({
    required this.id,
    required this.proposalId,
    required this.title,
    required this.description,
    required this.proposer,
    required this.status,
    required this.forVotes,
    required this.againstVotes,
    required this.abstainVotes,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
  });

  /// Calculate total votes
  BigInt get totalVotes => forVotes + againstVotes + abstainVotes;

  /// Calculate for vote percentage
  double get forPercentage {
    if (totalVotes == BigInt.zero) return 0.0;
    return (forVotes.toDouble() / totalVotes.toDouble()) * 100;
  }

  /// Calculate against vote percentage
  double get againstPercentage {
    if (totalVotes == BigInt.zero) return 0.0;
    return (againstVotes.toDouble() / totalVotes.toDouble()) * 100;
  }

  /// Calculate abstain vote percentage
  double get abstainPercentage {
    if (totalVotes == BigInt.zero) return 0.0;
    return (abstainVotes.toDouble() / totalVotes.toDouble()) * 100;
  }

  /// Format votes for display (in VLTC tokens)
  String get forVotesFormatted => _formatVotes(forVotes);
  String get againstVotesFormatted => _formatVotes(againstVotes);
  String get abstainVotesFormatted => _formatVotes(abstainVotes);
  String get totalVotesFormatted => _formatVotes(totalVotes);

  String _formatVotes(BigInt votes) {
    final vltc = votes.toDouble() / 1e18;
    if (vltc >= 1000000) {
      return '${(vltc / 1000000).toStringAsFixed(2)}M';
    } else if (vltc >= 1000) {
      return '${(vltc / 1000).toStringAsFixed(2)}K';
    } else {
      return vltc.toStringAsFixed(2);
    }
  }

  /// Shortened proposer address
  String get proposerShort =>
      '${proposer.hex.substring(0, 6)}...${proposer.hex.substring(proposer.hex.length - 4)}';

  /// Time remaining (human readable)
  String get timeRemaining {
    final now = DateTime.now();
    if (endTime.isBefore(now)) {
      return 'Ended';
    }

    final difference = endTime.difference(now);
    if (difference.inDays > 0) {
      return '${difference.inDays}d remaining';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h remaining';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m remaining';
    } else {
      return 'Ending soon';
    }
  }

  factory DAOProposal.fromJson(Map<String, dynamic> json) {
    return DAOProposal(
      id: json['id'] ?? json['_id'] ?? '',
      proposalId: json['proposalId'] ?? '',
      title: json['title'] ?? 'Untitled Proposal',
      description: json['description'] ?? '',
      proposer: EthereumAddress.fromHex(json['proposer'] ?? '0x0000000000000000000000000000000000000000'),
      status: ProposalStatus.fromValue(json['status'] ?? 1),
      forVotes: BigInt.parse(json['forVotes']?.toString() ?? '0'),
      againstVotes: BigInt.parse(json['againstVotes']?.toString() ?? '0'),
      abstainVotes: BigInt.parse(json['abstainVotes']?.toString() ?? '0'),
      startTime: DateTime.parse(json['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(json['endTime'] ?? DateTime.now().add(const Duration(days: 7)).toIso8601String()),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'proposalId': proposalId,
        'title': title,
        'description': description,
        'proposer': proposer.hex,
        'status': status.value,
        'forVotes': forVotes.toString(),
        'againstVotes': againstVotes.toString(),
        'abstainVotes': abstainVotes.toString(),
        'forPercentage': forPercentage,
        'againstPercentage': againstPercentage,
        'abstainPercentage': abstainPercentage,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'timeRemaining': timeRemaining,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Vote Receipt Model
class VoteReceipt {
  final String proposalId;
  final EthereumAddress voter;
  final bool support; // true = for, false = against
  final BigInt weight;
  final DateTime timestamp;
  final String txHash;

  VoteReceipt({
    required this.proposalId,
    required this.voter,
    required this.support,
    required this.weight,
    required this.timestamp,
    required this.txHash,
  });

  String get supportString => support ? 'For' : 'Against';
  String get weightFormatted => (weight.toDouble() / 1e18).toStringAsFixed(2);

  factory VoteReceipt.fromJson(Map<String, dynamic> json) {
    return VoteReceipt(
      proposalId: json['proposalId'] ?? '',
      voter: EthereumAddress.fromHex(json['voter'] ?? '0x0000000000000000000000000000000000000000'),
      support: json['support'] ?? true,
      weight: BigInt.parse(json['weight']?.toString() ?? '0'),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      txHash: json['txHash'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'proposalId': proposalId,
        'voter': voter.hex,
        'support': support,
        'weight': weight.toString(),
        'timestamp': timestamp.toIso8601String(),
        'txHash': txHash,
      };
}

/// DAO Service
///
/// Handles all DAO-related operations including:
/// - Loading proposals from backend
/// - Voting on proposals
/// - Creating proposals
/// - Viewing voting history
/// - Checking treasury balance
class DAOService {
  final Web3Service _web3Service;
  final Dio _dio = Dio();

  DAOService(this._web3Service);

  /// Get all proposals
  Future<List<DAOProposal>> getProposals({ProposalStatus? statusFilter}) async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.daoServiceUrl}${ApiEndpoints.daoProposals}',
        queryParameters: statusFilter != null ? {'status': statusFilter.value} : null,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.map((p) => DAOProposal.fromJson(p)).toList();
        } else if (data is Map && data['proposals'] != null) {
          return (data['proposals'] as List).map((p) => DAOProposal.fromJson(p)).toList();
        }
      }

      return [];
    } catch (e) {
      print('Error getting proposals: $e');
      return [];
    }
  }

  /// Get active proposals only
  Future<List<DAOProposal>> getActiveProposals() async {
    return getProposals(statusFilter: ProposalStatus.active);
  }

  /// Get proposal by ID
  Future<DAOProposal?> getProposalById(String proposalId) async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.daoServiceUrl}${ApiEndpoints.daoProposals}/$proposalId',
      );

      if (response.statusCode == 200) {
        return DAOProposal.fromJson(response.data);
      }

      return null;
    } catch (e) {
      print('Error getting proposal $proposalId: $e');
      return null;
    }
  }

  /// Cast vote on a proposal
  ///
  /// Parameters:
  /// - proposalId: The proposal to vote on
  /// - support: 0 = against, 1 = for, 2 = abstain
  /// - reason: Optional reason for the vote
  ///
  /// Returns: Transaction hash
  Future<String> castVote({
    required String proposalId,
    required int support, // 0 = against, 1 = for, 2 = abstain
    String reason = '',
  }) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.daoServiceUrl}${ApiEndpoints.daoVoting}/cast',
        data: {
          'proposalId': proposalId,
          'support': support,
          'reason': reason,
          'voter': _web3Service.userAddressOrNull?.hex,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['txHash'] ?? response.data['transactionHash'] ?? '';
      }

      throw Exception('Failed to cast vote: ${response.statusCode}');
    } catch (e) {
      print('Error casting vote: $e');
      rethrow;
    }
  }

  /// Get voting history for a user
  Future<List<VoteReceipt>> getVotingHistory(EthereumAddress voter) async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.daoServiceUrl}${ApiEndpoints.daoVoting}/history/${voter.hex}',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.map((v) => VoteReceipt.fromJson(v)).toList();
        } else if (data is Map && data['votes'] != null) {
          return (data['votes'] as List).map((v) => VoteReceipt.fromJson(v)).toList();
        }
      }

      return [];
    } catch (e) {
      print('Error getting voting history: $e');
      return [];
    }
  }

  /// Check if user has voted on a proposal
  Future<bool> hasVoted(String proposalId, EthereumAddress voter) async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.daoServiceUrl}${ApiEndpoints.daoVoting}/has-voted',
        queryParameters: {
          'proposalId': proposalId,
          'voter': voter.hex,
        },
      );

      if (response.statusCode == 200) {
        return response.data['hasVoted'] ?? false;
      }

      return false;
    } catch (e) {
      print('Error checking if voted: $e');
      return false;
    }
  }

  /// Get voting power for a user
  Future<BigInt> getVotingPower(EthereumAddress voter) async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.daoServiceUrl}${ApiEndpoints.daoVoting}/power/${voter.hex}',
      );

      if (response.statusCode == 200) {
        final power = response.data['votingPower'] ?? response.data['power'] ?? '0';
        return BigInt.parse(power.toString());
      }

      return BigInt.zero;
    } catch (e) {
      print('Error getting voting power: $e');
      return BigInt.zero;
    }
  }

  /// Get treasury balance
  Future<Map<String, dynamic>> getTreasuryBalance() async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.daoServiceUrl}${ApiEndpoints.daoTreasuryBalance}',
      );

      if (response.statusCode == 200) {
        return {
          'vltc': response.data['vltc'] ?? response.data['balance'] ?? '0',
          'eth': response.data['eth'] ?? '0',
          'usd': response.data['usd'] ?? '0',
        };
      }

      return {'vltc': '0', 'eth': '0', 'usd': '0'};
    } catch (e) {
      print('Error getting treasury balance: $e');
      return {'vltc': '0', 'eth': '0', 'usd': '0'};
    }
  }

  /// Create a new proposal (requires VLTC threshold)
  Future<String> createProposal({
    required String title,
    required String description,
    required List<String> targets,
    required List<BigInt> values,
    required List<String> calldatas,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.daoServiceUrl}${ApiEndpoints.daoProposals}',
        data: {
          'title': title,
          'description': description,
          'proposer': _web3Service.userAddressOrNull?.hex,
          'targets': targets,
          'values': values.map((v) => v.toString()).toList(),
          'calldatas': calldatas,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['proposalId'] ?? response.data['id'] ?? '';
      }

      throw Exception('Failed to create proposal: ${response.statusCode}');
    } catch (e) {
      print('Error creating proposal: $e');
      rethrow;
    }
  }

  /// Check if user can create proposals (has enough VLTC)
  Future<bool> canCreateProposal(EthereumAddress user) async {
    try {
      final votingPower = await getVotingPower(user);
      final threshold = BigInt.from(1000) * BigInt.from(10).pow(18); // 1000 VLTC
      return votingPower >= threshold;
    } catch (e) {
      print('Error checking proposal creation eligibility: $e');
      return false;
    }
  }
}
