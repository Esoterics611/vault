import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';

class DAOPage extends ConsumerStatefulWidget {
  const DAOPage({super.key});

  @override
  ConsumerState<DAOPage> createState() => _DAOPageState();
}

class _DAOPageState extends ConsumerState<DAOPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dio = Dio();

  List<dynamic> _proposals = [];
  Map<String, dynamic>? _treasuryData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDAOData();
  }

  Future<void> _loadDAOData() async {
    setState(() => _isLoading = true);

    try {
      // Load proposals
      final proposalsResponse = await _dio.get(
        '${ApiEndpoints.daoServiceUrl}${ApiEndpoints.daoProposals}',
      );

      // Load treasury balance
      final treasuryResponse = await _dio.get(
        '${ApiEndpoints.daoServiceUrl}${ApiEndpoints.daoTreasuryBalance}',
      );

      setState(() {
        _proposals = proposalsResponse.data is List ? proposalsResponse.data : [];
        _treasuryData = treasuryResponse.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _proposals = _getMockProposals();
        _treasuryData = {'balance': '0', 'vltc': '0'};
        _isLoading = false;
      });
    }
  }

  List<dynamic> _getMockProposals() {
    return [
      {
        'id': '1',
        'title': 'Increase Creator Rewards',
        'description': 'Proposal to increase rewards for content creators',
        'status': 'active',
        'votesFor': '1500',
        'votesAgainst': '500',
        'endTime': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
      },
      {
        'id': '2',
        'title': 'Platform Fee Reduction',
        'description': 'Reduce marketplace fees from 2.5% to 2%',
        'status': 'active',
        'votesFor': '2000',
        'votesAgainst': '800',
        'endTime': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      },
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProposalsTab(),
                _buildTreasuryTab(),
                _buildMyVotesTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateProposal,
        icon: const Icon(Icons.add),
        label: const Text('New Proposal'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildProposalsTab() {
    if (_proposals.isEmpty) {
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
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDAOData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _proposals.length,
        itemBuilder: (context, index) {
          final proposal = _proposals[index];
          return _ProposalCard(
            proposal: proposal,
            onTap: () => _showProposalDetails(proposal),
          );
        },
      ),
    );
  }

  Widget _buildTreasuryTab() {
    final balance = _treasuryData?['balance'] ?? '0';
    final vltc = _treasuryData?['vltc'] ?? '0';

    return SingleChildScrollView(
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
                    '≈ $balance ETH',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recent Transactions
          Text(
            'Recent Transactions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No recent transactions',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
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

  void _showProposalDetails(dynamic proposal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProposalDetailsPage(proposal: proposal),
      ),
    );
  }

  void _showCreateProposal() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create proposal functionality coming soon')),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final dynamic proposal;
  final VoidCallback onTap;

  const _ProposalCard({
    required this.proposal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final votesFor = int.tryParse(proposal['votesFor'] ?? '0') ?? 0;
    final votesAgainst = int.tryParse(proposal['votesAgainst'] ?? '0') ?? 0;
    final totalVotes = votesFor + votesAgainst;
    final forPercentage = totalVotes > 0 ? (votesFor / totalVotes * 100) : 0;

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
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      proposal['status']?.toUpperCase() ?? 'ACTIVE',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                proposal['title'] ?? 'Untitled Proposal',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                proposal['description'] ?? '',
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
                              'For: ${forPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Against: ${(100 - forPercentage).toStringAsFixed(0)}%',
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
                            value: forPercentage / 100,
                            backgroundColor: Colors.red[100],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            minHeight: 8,
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
}

// Proposal Details Page
class ProposalDetailsPage extends StatelessWidget {
  final dynamic proposal;

  const ProposalDetailsPage({super.key, required this.proposal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proposal Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                proposal['status']?.toUpperCase() ?? 'ACTIVE',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              proposal['title'] ?? 'Untitled Proposal',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              proposal['description'] ?? 'No description',
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
                            votes: proposal['votesFor'] ?? '0',
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _VoteResult(
                            label: 'Against',
                            votes: proposal['votesAgainst'] ?? '0',
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _vote(context, true),
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
                  onPressed: () => _vote(context, false),
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
      ),
    );
  }

  void _vote(BuildContext context, bool support) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(support ? 'Vote For' : 'Vote Against'),
        content: const Text('This will initiate a blockchain transaction.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement voting logic
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(support ? 'Voted For!' : 'Voted Against!'),
                  backgroundColor: support ? Colors.green : Colors.red,
                ),
              );
            },
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
  final Color color;

  const _VoteResult({
    required this.label,
    required this.votes,
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
        ],
      ),
    );
  }
}
