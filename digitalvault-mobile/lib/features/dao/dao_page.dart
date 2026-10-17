import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/dao_provider.dart';
import '../../core/services/dao_service.dart';

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

    // Load DAO data when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(daoProvider.notifier).loadDAOData();
    });
  }

  Future<void> _loadDAOData() async {
    await ref.read(daoProvider.notifier).loadDAOData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daoState = ref.watch(daoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DAO Governance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Proposals'),
            Tab(text: 'Treasury'),
            Tab(text: 'My Votes'),
          ],
        ),
      ),
      body: daoState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : daoState.error != null
              ? _buildErrorState(daoState.error!)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProposalsTab(daoState),
                    _buildTreasuryTab(daoState),
                    _buildMyVotesTab(daoState),
                  ],
                ),
      floatingActionButton: daoState.canCreateProposals
          ? FloatingActionButton.extended(
              onPressed: _showCreateProposal,
              icon: const Icon(Icons.add),
              label: const Text('New Proposal'),
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Error Loading DAO Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDAOData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalsTab(DAOState daoState) {
    final proposals = daoState.activeProposals;

    if (proposals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.how_to_vote_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No active proposals',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later or create one',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDAOData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: proposals.length,
        itemBuilder: (context, index) {
          final proposal = proposals[index];
          return _ProposalCard(
            proposal: proposal,
            onTap: () => _showProposalDetails(proposal),
          );
        },
      ),
    );
  }

  Widget _buildTreasuryTab(DAOState daoState) {
    final vltc = daoState.treasuryVLTC;
    final eth = daoState.treasuryETH;

    return RefreshIndicator(
      onRefresh: () => ref.read(daoProvider.notifier).loadTreasury(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Treasury Balance Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Treasury Balance',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$vltc VLTC',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '≈ $eth ETH',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // User Voting Power Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Your Voting Power',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${daoState.votingPowerFormatted} VLTC',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                    if (!daoState.canCreateProposals) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Need 1000 VLTC to create proposals',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Statistics
            Text(
              'Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Proposals',
                    value: daoState.proposals.length.toString(),
                    icon: Icons.description_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Active',
                    value: daoState.activeProposals.length.toString(),
                    icon: Icons.how_to_vote_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyVotesTab(DAOState daoState) {
    final myVotes = daoState.myVotes;

    if (myVotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ballot_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No voting history',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Cast your first vote on a proposal',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(daoProvider.notifier).loadVotingHistory(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: myVotes.length,
        itemBuilder: (context, index) {
          final vote = myVotes[index];
          return _VoteHistoryCard(vote: vote);
        },
      ),
    );
  }

  void _showProposalDetails(DAOProposal proposal) {
    ref.read(daoProvider.notifier).selectProposal(proposal);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProposalDetailsPage(proposal: proposal),
      ),
    );
  }

  void _showCreateProposal() {
    showDialog(
      context: context,
      builder: (context) => const CreateProposalDialog(),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final DAOProposal proposal;
  final VoidCallback onTap;

  const _ProposalCard({
    required this.proposal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      proposal.status.displayName.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    proposal.timeRemaining,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                proposal.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                proposal.description,
                style: TextStyle(color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Vote Progress
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'For: ${proposal.forPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Against: ${proposal.againstPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: proposal.forPercentage / 100,
                            backgroundColor: Colors.red[100],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: ${proposal.totalVotesFormatted} VLTC',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (proposal.status) {
      case ProposalStatus.active:
        return Colors.green;
      case ProposalStatus.succeeded:
        return Colors.blue;
      case ProposalStatus.defeated:
        return Colors.red;
      case ProposalStatus.executed:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class _VoteHistoryCard extends StatelessWidget {
  final VoteReceipt vote;

  const _VoteHistoryCard({required this.vote});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  vote.support ? Icons.thumb_up : Icons.thumb_down,
                  color: vote.support ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Voted ${vote.supportString}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: vote.support ? Colors.green : Colors.red,
                  ),
                ),
                const Spacer(),
                Text(
                  '${vote.weightFormatted} VLTC',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Proposal ID: ${vote.proposalId.substring(0, 10)}...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Voted on: ${vote.timestamp.toString().substring(0, 16)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF6C63FF), size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Proposal Details Page
class ProposalDetailsPage extends ConsumerWidget {
  final DAOProposal proposal;

  const ProposalDetailsPage({super.key, required this.proposal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daoState = ref.watch(daoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proposal Details'),
      ),
      body: daoState.isVoting
          ? _buildVotingProgress(daoState)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      proposal.status.displayName.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    proposal.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // Time remaining
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        proposal.timeRemaining,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Proposer
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'By ${proposal.proposerShort}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    proposal.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),

                  // Vote Results Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Results',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _VoteResult(
                                  label: 'For',
                                  votes: proposal.forVotesFormatted,
                                  percentage: proposal.forPercentage,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _VoteResult(
                                  label: 'Against',
                                  votes: proposal.againstVotesFormatted,
                                  percentage: proposal.againstPercentage,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          if (proposal.abstainVotes > BigInt.zero) ...[
                            const SizedBox(height: 12),
                            _VoteResult(
                              label: 'Abstain',
                              votes: proposal.abstainVotesFormatted,
                              percentage: proposal.abstainPercentage,
                              color: Colors.grey,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Error display
                  if (daoState.votingError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                daoState.votingError!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomNavigationBar: proposal.status.canVote && !daoState.isVoting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _vote(context, ref, 1), // For
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Vote For'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _vote(context, ref, 0), // Against
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Vote Against'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Color _getStatusColor() {
    switch (proposal.status) {
      case ProposalStatus.active:
        return Colors.green;
      case ProposalStatus.succeeded:
        return Colors.blue;
      case ProposalStatus.defeated:
        return Colors.red;
      case ProposalStatus.executed:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildVotingProgress(DAOState state) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text(
                'Casting Vote...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: state.votingProgress,
              ),
              const SizedBox(height: 8),
              Text(
                '${(state.votingProgress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _vote(BuildContext context, WidgetRef ref, int support) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(support == 1 ? 'Vote For' : 'Vote Against'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Proposal: ${proposal.title}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will initiate a blockchain transaction.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Cast vote
              final success = await ref.read(daoProvider.notifier).castVote(
                    proposalId: proposal.proposalId,
                    support: support,
                  );

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(support == 1 ? 'Voted For!' : 'Voted Against!'),
                      backgroundColor: support == 1 ? Colors.green : Colors.red,
                    ),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ref.read(daoProvider).votingError ?? 'Vote failed',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: support == 1 ? Colors.green : Colors.red,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _VoteResult extends StatelessWidget {
  final String label;
  final String votes;
  final double percentage;
  final Color color;

  const _VoteResult({
    required this.label,
    required this.votes,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            votes,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'VLTC',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Create Proposal Dialog
class CreateProposalDialog extends ConsumerStatefulWidget {
  const CreateProposalDialog({super.key});

  @override
  ConsumerState<CreateProposalDialog> createState() => _CreateProposalDialogState();
}

class _CreateProposalDialogState extends ConsumerState<CreateProposalDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daoState = ref.watch(daoProvider);

    return AlertDialog(
      title: const Text('Create Proposal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
            if (daoState.creationError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        daoState.creationError!,
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: daoState.isCreatingProposal ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: daoState.isCreatingProposal ? null : _createProposal,
          child: daoState.isCreatingProposal
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createProposal() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await ref.read(daoProvider.notifier).createProposal(
          title: _titleController.text,
          description: _descriptionController.text,
        );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proposal created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
