import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/governance_service.dart';
import '../../core/providers/governance_provider.dart';
import '../../core/contracts/dao_governor_contract.dart';

/// Detailed view of a single proposal with voting interface
class ProposalDetailsPage extends ConsumerStatefulWidget {
  final Proposal proposal;

  const ProposalDetailsPage({
    super.key,
    required this.proposal,
  });

  @override
  ConsumerState<ProposalDetailsPage> createState() => _ProposalDetailsPageState();
}

class _ProposalDetailsPageState extends ConsumerState<ProposalDetailsPage> {
  bool _isVoting = false;
  bool _isQueueing = false;
  bool _isExecuting = false;

  @override
  Widget build(BuildContext context) {
    final userAddress = ref.watch(userAddressProvider);
    final hasVotedAsync = ref.watch(
      hasVotedProvider((proposalId: widget.proposal.proposalId, voterAddress: userAddress ?? '')),
    );
    final votingPowerAsync = ref.watch(userVotingPowerProvider(userAddress ?? ''));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('Proposal Details', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with state badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStateBadge(widget.proposal.state),
                  const SizedBox(height: 16),
                  Text(
                    widget.proposal.description.split('\n').first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.white60, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'By ${_shortenAddress(widget.proposal.proposer)}',
                        style: const TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Voting results
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Voting Results',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  _buildVoteBar(
                    label: 'For',
                    votes: widget.proposal.forVotes,
                    percentage: widget.proposal.forPercentage,
                    color: Colors.green,
                  ),

                  const SizedBox(height: 12),

                  _buildVoteBar(
                    label: 'Against',
                    votes: widget.proposal.againstVotes,
                    percentage: widget.proposal.againstPercentage,
                    color: Colors.red,
                  ),

                  const SizedBox(height: 12),

                  _buildVoteBar(
                    label: 'Abstain',
                    votes: widget.proposal.abstainVotes,
                    percentage: widget.proposal.abstainPercentage,
                    color: Colors.grey,
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Votes',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          '${widget.proposal.totalVotes.toStringAsFixed(0)} VLTC',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.proposal.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Voting power info
            if (widget.proposal.canVote)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: votingPowerAsync.when(
                  data: (votingPower) {
                    return Container(
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
                              const Icon(Icons.how_to_vote, color: Color(0xFF6C63FF), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Your Voting Power',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(votingPower.toDouble() / 1e18).toStringAsFixed(0)} VLTC',
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

            const SizedBox(height: 24),

            // Voting buttons or action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: hasVotedAsync.when(
                data: (hasVoted) {
                  if (widget.proposal.canVote && !hasVoted) {
                    return _buildVotingButtons();
                  } else if (widget.proposal.canVote && hasVoted) {
                    return _buildAlreadyVotedMessage();
                  } else if (widget.proposal.canQueue) {
                    return _buildQueueButton();
                  } else if (widget.proposal.canExecute) {
                    return _buildExecuteButton();
                  } else {
                    return _buildProposalEndedMessage();
                  }
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            const SizedBox(height: 24),

            // Timeline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Timeline',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineItem(
                    'Voting Started',
                    'Block ${widget.proposal.voteStart}',
                    true,
                  ),
                  _buildTimelineItem(
                    'Voting Ends',
                    'Block ${widget.proposal.voteEnd}',
                    widget.proposal.state.value >= ProposalState.succeeded.value,
                  ),
                  if (widget.proposal.isQueued || widget.proposal.isExecuted)
                    _buildTimelineItem(
                      'Queued',
                      'Waiting for timelock',
                      widget.proposal.isQueued || widget.proposal.isExecuted,
                    ),
                  if (widget.proposal.isExecuted)
                    _buildTimelineItem(
                      'Executed',
                      'Proposal enacted',
                      true,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStateBadge(ProposalState state) {
    Color color;
    IconData icon;
    String label;

    switch (state) {
      case ProposalState.pending:
        color = Colors.orange;
        icon = Icons.schedule;
        label = 'Pending';
        break;
      case ProposalState.active:
        color = Colors.blue;
        icon = Icons.how_to_vote;
        label = 'Active';
        break;
      case ProposalState.canceled:
        color = Colors.grey;
        icon = Icons.cancel;
        label = 'Canceled';
        break;
      case ProposalState.defeated:
        color = Colors.red;
        icon = Icons.thumb_down;
        label = 'Defeated';
        break;
      case ProposalState.succeeded:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Succeeded';
        break;
      case ProposalState.queued:
        color = Colors.purple;
        icon = Icons.queue;
        label = 'Queued';
        break;
      case ProposalState.expired:
        color = Colors.grey;
        icon = Icons.timer_off;
        label = 'Expired';
        break;
      case ProposalState.executed:
        color = Colors.green;
        icon = Icons.done_all;
        label = 'Executed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteBar({
    required String label,
    required BigInt votes,
    required double percentage,
    required Color color,
  }) {
    final displayVotes = (votes.toDouble() / 1e18).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              '$displayVotes VLTC (${percentage.toStringAsFixed(1)}%)',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildVotingButtons() {
    return Column(
      children: [
        const Text(
          'Cast Your Vote',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isVoting ? null : () => _castVote(VoteSupport.for_),
                icon: const Icon(Icons.thumb_up, size: 20),
                label: const Text('For'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isVoting ? null : () => _castVote(VoteSupport.against),
                icon: const Icon(Icons.thumb_down, size: 20),
                label: const Text('Against'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isVoting ? null : () => _castVote(VoteSupport.abstain),
            icon: const Icon(Icons.horizontal_rule, size: 20),
            label: const Text('Abstain'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.grey),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlreadyVotedMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You have already voted on this proposal',
              style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isQueueing ? null : _queueProposal,
        icon: const Icon(Icons.queue),
        label: const Text('Queue for Execution'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildExecuteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isExecuting ? null : _executeProposal,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Execute Proposal'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildProposalEndedMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.grey, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Voting has ended for this proposal',
              style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, String subtitle, bool isComplete) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isComplete ? const Color(0xFF6C63FF).withOpacity(0.2) : Colors.white12,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isComplete ? const Color(0xFF6C63FF) : Colors.white24,
                width: 2,
              ),
            ),
            child: Icon(
              isComplete ? Icons.check : Icons.circle_outlined,
              color: isComplete ? const Color(0xFF6C63FF) : Colors.white24,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isComplete ? Colors.white : Colors.white60,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortenAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  Future<void> _castVote(VoteSupport support) async {
    setState(() => _isVoting = true);

    try {
      final governanceService = ref.read(governanceServiceProvider);

      await governanceService.castVote(
        proposalId: widget.proposal.proposalId,
        support: support,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vote cast successfully: ${support.name}'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(hasVotedProvider);
        ref.invalidate(proposalVotesProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cast vote: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  Future<void> _queueProposal() async {
    setState(() => _isQueueing = true);

    try {
      final governanceService = ref.read(governanceServiceProvider);

      await governanceService.queueProposal(
        proposalId: widget.proposal.proposalId,
        targets: widget.proposal.targets,
        values: widget.proposal.values,
        calldatas: widget.proposal.calldatas,
        description: widget.proposal.description,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proposal queued successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(proposalStateProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to queue proposal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isQueueing = false);
      }
    }
  }

  Future<void> _executeProposal() async {
    setState(() => _isExecuting = true);

    try {
      final governanceService = ref.read(governanceServiceProvider);

      await governanceService.executeProposal(
        proposalId: widget.proposal.proposalId,
        targets: widget.proposal.targets,
        values: widget.proposal.values,
        calldatas: widget.proposal.calldatas,
        description: widget.proposal.description,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proposal executed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(proposalStateProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to execute proposal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }
}
