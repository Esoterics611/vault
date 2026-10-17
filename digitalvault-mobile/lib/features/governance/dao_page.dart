import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/governance_provider.dart';
import 'create_proposal_dialog.dart';

/// Main DAO governance page with tabs for proposals, voting, and delegation
class DAOPage extends ConsumerStatefulWidget {
  const DAOPage({super.key});

  @override
  ConsumerState<DAOPage> createState() => _DAOPageState();
}

class _DAOPageState extends ConsumerState<DAOPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAddress = ref.watch(userAddressProvider);
    final votingPowerAsync = ref.watch(userVotingPowerProvider(userAddress ?? ''));
    final tokenBalanceAsync = ref.watch(userTokenBalanceProvider(userAddress ?? ''));
    final delegateAsync = ref.watch(userDelegateProvider(userAddress ?? ''));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('DAO Governance', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C63FF),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Proposals'),
            Tab(text: 'My Votes'),
            Tab(text: 'Delegation'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header with voting power and token balance
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.how_to_vote,
                        label: 'Voting Power',
                        valueAsync: votingPowerAsync,
                        suffix: 'VLTC',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.account_balance_wallet,
                        label: 'Token Balance',
                        valueAsync: tokenBalanceAsync,
                        suffix: 'VLTC',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Delegation status
                delegateAsync.when(
                  data: (delegate) {
                    final isDelegatedToSelf = delegate.toLowerCase() == userAddress?.toLowerCase();
                    final isNotDelegated = delegate == '0x0000000000000000000000000000000000000000';

                    if (isNotDelegated || isDelegatedToSelf) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Delegate to yourself to activate voting power',
                                style: TextStyle(color: Colors.orange, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _delegateToSelf(),
                              child: const Text('Delegate', style: TextStyle(color: Colors.orange)),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Delegated to: ${_shortenAddress(delegate)}',
                              style: const TextStyle(color: Colors.green, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProposalsTab(),
                _buildMyVotesTab(),
                _buildDelegationTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateProposalDialog(),
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.add),
        label: const Text('New Proposal'),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required AsyncValue<BigInt> valueAsync,
    required String suffix,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6C63FF), size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          valueAsync.when(
            data: (value) {
              final displayValue = (value.toDouble() / 1e18).toStringAsFixed(0);
              return Text(
                '$displayValue $suffix',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
            loading: () => const CircularProgressIndicator(strokeWidth: 2),
            error: (_, __) => const Text(
              '0',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalsTab() {
    // TODO: This will be implemented with a list of proposals from backend
    // For now, showing placeholder
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ballot_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No proposals yet',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Create the first proposal to get started',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMyVotesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.how_to_vote_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No votes cast yet',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Your voting history will appear here',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDelegationTab() {
    final userAddress = ref.watch(userAddressProvider);
    final delegateAsync = ref.watch(userDelegateProvider(userAddress ?? ''));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vote Delegation',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Delegate your voting power to participate in governance. You can delegate to yourself or another trusted address.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Current delegation status
          delegateAsync.when(
            data: (delegate) {
              final isDelegatedToSelf = delegate.toLowerCase() == userAddress?.toLowerCase();
              final isNotDelegated = delegate == '0x0000000000000000000000000000000000000000';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Delegate',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isNotDelegated ? 'Not delegated' : (isDelegatedToSelf ? 'Self' : delegate),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('Error loading delegate', style: TextStyle(color: Colors.red)),
          ),

          const SizedBox(height: 24),

          // Delegate to self button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _delegateToSelf(),
              icon: const Icon(Icons.person),
              label: const Text('Delegate to Myself'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Delegate to another address
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDelegateToOtherDialog(),
              icon: const Icon(Icons.people),
              label: const Text('Delegate to Another Address'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF6C63FF)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Info box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: const Color(0xFF6C63FF), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'About Delegation',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoItem('• You must delegate to activate your voting power'),
                _buildInfoItem('• Delegation doesn\'t transfer tokens, only voting rights'),
                _buildInfoItem('• You can change your delegate at any time'),
                _buildInfoItem('• Most users delegate to themselves'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  String _shortenAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  Future<void> _delegateToSelf() async {
    final userAddress = ref.read(userAddressProvider);
    if (userAddress == null) {
      _showError('No wallet connected');
      return;
    }

    try {
      final governanceService = ref.read(governanceServiceProvider);

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      await governanceService.delegateVotes(userAddress);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully delegated to yourself'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(userDelegateProvider);
        ref.invalidate(userVotingPowerProvider);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showError('Failed to delegate: ${e.toString()}');
      }
    }
  }

  Future<void> _showDelegateToOtherDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Delegate to Address', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Delegate Address',
            labelStyle: TextStyle(color: Colors.white70),
            hintText: '0x...',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text('Delegate'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final governanceService = ref.read(governanceServiceProvider);

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );
        }

        await governanceService.delegateVotes(result);

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully delegated to ${_shortenAddress(result)}'),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(userDelegateProvider);
          ref.invalidate(userVotingPowerProvider);
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          _showError('Failed to delegate: ${e.toString()}');
        }
      }
    }
  }

  void _showCreateProposalDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateProposalDialog(),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
