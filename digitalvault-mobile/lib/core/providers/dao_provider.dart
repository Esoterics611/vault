import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3dart/web3dart.dart';
import '../services/dao_service.dart';
import '../services/web3_service.dart';
import 'wallet_provider.dart';

/// DAO State
class DAOState {
  final List<DAOProposal> proposals;
  final List<DAOProposal> activeProposals;
  final List<VoteReceipt> myVotes;
  final Map<String, dynamic> treasury;
  final bool isLoading;
  final String? error;
  final DAOProposal? selectedProposal;

  /// Voting state
  final bool isVoting;
  final String? votingError;
  final double votingProgress; // 0.0 to 1.0

  /// Proposal creation state
  final bool isCreatingProposal;
  final String? creationError;

  /// User state
  final BigInt votingPower;
  final bool canCreateProposals;

  DAOState({
    this.proposals = const [],
    this.activeProposals = const [],
    this.myVotes = const [],
    Map<String, dynamic>? treasury,
    this.isLoading = false,
    this.error,
    this.selectedProposal,
    this.isVoting = false,
    this.votingError,
    this.votingProgress = 0.0,
    this.isCreatingProposal = false,
    this.creationError,
    BigInt? votingPower,
    this.canCreateProposals = false,
  })  : treasury = treasury ?? const {},
        votingPower = votingPower ?? BigInt.zero;

  DAOState copyWith({
    List<DAOProposal>? proposals,
    List<DAOProposal>? activeProposals,
    List<VoteReceipt>? myVotes,
    Map<String, dynamic>? treasury,
    bool? isLoading,
    String? error,
    DAOProposal? selectedProposal,
    bool? isVoting,
    String? votingError,
    double? votingProgress,
    bool? isCreatingProposal,
    String? creationError,
    BigInt? votingPower,
    bool? canCreateProposals,
  }) {
    return DAOState(
      proposals: proposals ?? this.proposals,
      activeProposals: activeProposals ?? this.activeProposals,
      myVotes: myVotes ?? this.myVotes,
      treasury: treasury ?? this.treasury,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedProposal: selectedProposal ?? this.selectedProposal,
      isVoting: isVoting ?? this.isVoting,
      votingError: votingError,
      votingProgress: votingProgress ?? this.votingProgress,
      isCreatingProposal: isCreatingProposal ?? this.isCreatingProposal,
      creationError: creationError,
      votingPower: votingPower ?? this.votingPower,
      canCreateProposals: canCreateProposals ?? this.canCreateProposals,
    );
  }

  /// Get formatted voting power
  String get votingPowerFormatted {
    final vltc = votingPower.toDouble() / 1e18;
    return vltc.toStringAsFixed(2);
  }

  /// Get formatted treasury balance
  String get treasuryVLTC => treasury['vltc']?.toString() ?? '0';
  String get treasuryETH => treasury['eth']?.toString() ?? '0';
}

/// DAO Notifier
class DAONotifier extends StateNotifier<DAOState> {
  final DAOService _daoService;
  final Web3Service _web3Service;
  final Ref _ref;

  DAONotifier(
    this._daoService,
    this._web3Service,
    this._ref,
  ) : super(DAOState());

  /// Load all DAO data
  Future<void> loadDAOData() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      // Load proposals
      final proposals = await _daoService.getProposals();
      final activeProposals = proposals.where((p) => p.status.isActive).toList();

      // Load treasury
      final treasury = await _daoService.getTreasuryBalance();

      // Load user-specific data if wallet connected
      final walletState = _ref.read(walletProvider);
      BigInt votingPower = BigInt.zero;
      bool canCreate = false;
      List<VoteReceipt> myVotes = [];

      if (walletState.isConnected && walletState.address != null) {
        final userAddress = EthereumAddress.fromHex(walletState.address!);

        // Load voting power
        try {
          votingPower = await _daoService.getVotingPower(userAddress);
          canCreate = await _daoService.canCreateProposal(userAddress);
        } catch (e) {
          print('Error loading user voting data: $e');
        }

        // Load voting history
        try {
          myVotes = await _daoService.getVotingHistory(userAddress);
        } catch (e) {
          print('Error loading voting history: $e');
        }
      }

      state = state.copyWith(
        proposals: proposals,
        activeProposals: activeProposals,
        treasury: treasury,
        myVotes: myVotes,
        votingPower: votingPower,
        canCreateProposals: canCreate,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load DAO data: $e',
      );
    }
  }

  /// Load only proposals (for refresh)
  Future<void> loadProposals() async {
    try {
      final proposals = await _daoService.getProposals();
      final activeProposals = proposals.where((p) => p.status.isActive).toList();

      state = state.copyWith(
        proposals: proposals,
        activeProposals: activeProposals,
      );
    } catch (e) {
      print('Error loading proposals: $e');
    }
  }

  /// Load treasury balance
  Future<void> loadTreasury() async {
    try {
      final treasury = await _daoService.getTreasuryBalance();
      state = state.copyWith(treasury: treasury);
    } catch (e) {
      print('Error loading treasury: $e');
    }
  }

  /// Load voting history
  Future<void> loadVotingHistory() async {
    final walletState = _ref.read(walletProvider);
    if (!walletState.isConnected || walletState.address == null) {
      return;
    }

    try {
      final userAddress = EthereumAddress.fromHex(walletState.address!);
      final myVotes = await _daoService.getVotingHistory(userAddress);

      state = state.copyWith(myVotes: myVotes);
    } catch (e) {
      print('Error loading voting history: $e');
    }
  }

  /// Select a proposal for viewing details
  void selectProposal(DAOProposal proposal) {
    state = state.copyWith(selectedProposal: proposal);
  }

  /// Clear selected proposal
  void clearSelectedProposal() {
    state = state.copyWith(selectedProposal: null);
  }

  /// Cast vote on a proposal
  ///
  /// Support values:
  /// - 0 = Against
  /// - 1 = For
  /// - 2 = Abstain
  Future<bool> castVote({
    required String proposalId,
    required int support,
    String reason = '',
  }) async {
    // Check wallet connection
    final walletState = _ref.read(walletProvider);
    if (!walletState.isConnected) {
      state = state.copyWith(votingError: 'Wallet not connected');
      return false;
    }

    state = state.copyWith(
      isVoting: true,
      votingProgress: 0.0,
      votingError: null,
    );

    try {
      // Step 1: Check if already voted (20%)
      state = state.copyWith(votingProgress: 0.2);
      final userAddress = EthereumAddress.fromHex(walletState.address!);
      final hasVoted = await _daoService.hasVoted(proposalId, userAddress);

      if (hasVoted) {
        throw Exception('You have already voted on this proposal');
      }

      // Step 2: Check voting power (40%)
      state = state.copyWith(votingProgress: 0.4);
      final votingPower = await _daoService.getVotingPower(userAddress);

      if (votingPower == BigInt.zero) {
        throw Exception('You have no voting power (need VLTC tokens)');
      }

      // Step 3: Submit vote (60%)
      state = state.copyWith(votingProgress: 0.6);
      final txHash = await _daoService.castVote(
        proposalId: proposalId,
        support: support,
        reason: reason,
      );

      // Step 4: Wait for confirmation (80%)
      state = state.copyWith(votingProgress: 0.8);
      if (txHash.isNotEmpty) {
        await _web3Service.waitForReceipt(txHash);
      }

      // Step 5: Complete (100%)
      state = state.copyWith(
        isVoting: false,
        votingProgress: 1.0,
        votingError: null,
      );

      // Reload proposals and voting history
      await loadProposals();
      await loadVotingHistory();

      return true;
    } catch (e) {
      state = state.copyWith(
        isVoting: false,
        votingError: e.toString(),
      );
      return false;
    }
  }

  /// Reset voting state
  void resetVotingState() {
    state = state.copyWith(
      isVoting: false,
      votingProgress: 0.0,
      votingError: null,
    );
  }

  /// Create a new proposal
  Future<bool> createProposal({
    required String title,
    required String description,
  }) async {
    // Check wallet connection
    final walletState = _ref.read(walletProvider);
    if (!walletState.isConnected) {
      state = state.copyWith(creationError: 'Wallet not connected');
      return false;
    }

    // Check if user can create proposals
    if (!state.canCreateProposals) {
      state = state.copyWith(
        creationError: 'You need at least 1000 VLTC to create proposals',
      );
      return false;
    }

    state = state.copyWith(
      isCreatingProposal: true,
      creationError: null,
    );

    try {
      // For MVP, we'll create a simple proposal without execution logic
      final proposalId = await _daoService.createProposal(
        title: title,
        description: description,
        targets: [], // Empty for text-only proposals
        values: [],
        calldatas: [],
      );

      state = state.copyWith(
        isCreatingProposal: false,
        creationError: null,
      );

      // Reload proposals
      await loadProposals();

      return true;
    } catch (e) {
      state = state.copyWith(
        isCreatingProposal: false,
        creationError: e.toString(),
      );
      return false;
    }
  }

  /// Reset proposal creation state
  void resetCreationState() {
    state = state.copyWith(
      isCreatingProposal: false,
      creationError: null,
    );
  }

  /// Refresh all data
  Future<void> refresh() async {
    await loadDAOData();
  }
}

/// DAO Provider
final daoProvider = StateNotifierProvider<DAONotifier, DAOState>((ref) {
  final web3Service = ref.watch(web3ServiceProvider);
  final daoService = DAOService(web3Service);

  return DAONotifier(
    daoService,
    web3Service,
    ref,
  );
});

// web3ServiceProvider is now imported from wallet_provider.dart
