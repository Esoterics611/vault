import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/governance_service.dart';
import '../contracts/dao_governor_contract.dart';
import 'wallet_provider.dart';

/// Provider for governance service
final governanceServiceProvider = Provider<GovernanceService>((ref) {
  final web3Service = ref.watch(web3ServiceProvider);
  final contractService = ref.watch(contractServiceProvider);

  return GovernanceService(
    web3Service,
    contractService,
  );
});

/// Provider for user's voting power
final userVotingPowerProvider = FutureProvider.family<BigInt, String>((ref, address) async {
  final governanceService = ref.watch(governanceServiceProvider);
  return await governanceService.getVotingPower(address);
});

/// Provider for user's token balance
final userTokenBalanceProvider = FutureProvider.family<BigInt, String>((ref, address) async {
  final governanceService = ref.watch(governanceServiceProvider);
  return await governanceService.getTokenBalance(address);
});

/// Provider for user's current delegate
final userDelegateProvider = FutureProvider.family<String, String>((ref, address) async {
  final governanceService = ref.watch(governanceServiceProvider);
  return await governanceService.getCurrentDelegate(address);
});

/// Provider for current user address
final userAddressProvider = Provider<String?>((ref) {
  final walletState = ref.watch(walletProvider);
  return walletState.address;
});

/// Provider for governance parameters
final governanceParamsProvider = FutureProvider<Map<String, BigInt>>((ref) async {
  final governanceService = ref.watch(governanceServiceProvider);
  return await governanceService.getGovernanceParams();
});

/// Provider for proposal state
final proposalStateProvider = FutureProvider.family<ProposalState, BigInt>((ref, proposalId) async {
  final governanceService = ref.watch(governanceServiceProvider);
  return await governanceService.getProposalState(proposalId);
});

/// Provider for proposal votes
final proposalVotesProvider = FutureProvider.family<Map<String, BigInt>, BigInt>((ref, proposalId) async {
  final governanceService = ref.watch(governanceServiceProvider);
  return await governanceService.getProposalVotes(proposalId);
});

/// Provider to check if user has voted
final hasVotedProvider = FutureProvider.family<bool, ({BigInt proposalId, String voterAddress})>((ref, params) async {
  final governanceService = ref.watch(governanceServiceProvider);
  return await governanceService.hasVoted(params.proposalId, params.voterAddress);
});
