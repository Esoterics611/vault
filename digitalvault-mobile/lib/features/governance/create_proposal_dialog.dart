import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3dart/web3dart.dart';
import 'dart:typed_data';
import '../../core/services/governance_service.dart';
import '../../core/providers/governance_provider.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/constants/contract_addresses.dart';

/// Dialog for creating a DAO proposal with step-by-step wizard
class CreateProposalDialog extends ConsumerStatefulWidget {
  const CreateProposalDialog({super.key});

  @override
  ConsumerState<CreateProposalDialog> createState() => _CreateProposalDialogState();
}

class _CreateProposalDialogState extends ConsumerState<CreateProposalDialog> {
  int _currentStep = 0;
  ProposalType _selectedType = ProposalType.feeChange;

  // Controllers for different proposal types
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _newFeeController = TextEditingController();
  final _customTargetController = TextEditingController();
  final _customCalldataController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _newFeeController.dispose();
    _customTargetController.dispose();
    _customCalldataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAddress = ref.watch(userAddressProvider);
    final votingPowerAsync = ref.watch(userVotingPowerProvider(userAddress ?? ''));
    final paramsAsync = ref.watch(governanceParamsProvider);

    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create Proposal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Voting power check
            votingPowerAsync.when(
              data: (votingPower) {
                return paramsAsync.when(
                  data: (params) {
                    final threshold = params['proposalThreshold'] ?? BigInt.zero;
                    final hasEnoughPower = votingPower >= threshold;

                    if (!hasEnoughPower) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You need ${(threshold.toDouble() / 1e18).toStringAsFixed(0)} VLTC voting power to create proposals. You have ${(votingPower.toDouble() / 1e18).toStringAsFixed(0)} VLTC.',
                                style: const TextStyle(color: Colors.orange, fontSize: 12),
                              ),
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
                          Text(
                            'Voting Power: ${(votingPower.toDouble() / 1e18).toStringAsFixed(0)} VLTC',
                            style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            // Stepper
            Expanded(
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: _onStepContinue,
                onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(_currentStep == 2 ? 'Submit Proposal' : 'Continue'),
                        ),
                        if (_currentStep > 0) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: details.onStepCancel,
                            child: const Text('Back', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text('Proposal Type', style: TextStyle(color: Colors.white)),
                    content: _buildTypeStep(),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Details', style: TextStyle(color: Colors.white)),
                    content: _buildDetailsStep(),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Review', style: TextStyle(color: Colors.white)),
                    content: _buildReviewStep(),
                    isActive: _currentStep >= 2,
                  ),
                ],
              ),
            ),

            // Error message
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Loading indicator
            if (_isSubmitting)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select the type of proposal you want to create:',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 16),

        _buildProposalTypeCard(
          type: ProposalType.feeChange,
          icon: Icons.attach_money,
          title: 'Marketplace Fee Change',
          description: 'Propose changing the platform fee for marketplace transactions',
        ),

        const SizedBox(height: 12),

        _buildProposalTypeCard(
          type: ProposalType.treasuryAction,
          icon: Icons.account_balance,
          title: 'Treasury Action',
          description: 'Propose withdrawing or transferring treasury funds',
        ),

        const SizedBox(height: 12),

        _buildProposalTypeCard(
          type: ProposalType.pauseContract,
          icon: Icons.pause_circle,
          title: 'Pause/Unpause Contract',
          description: 'Propose pausing or unpausing a contract in emergency situations',
        ),

        const SizedBox(height: 12),

        _buildProposalTypeCard(
          type: ProposalType.custom,
          icon: Icons.code,
          title: 'Custom Action',
          description: 'Advanced: Create a custom proposal with specific calldata',
        ),
      ],
    );
  }

  Widget _buildProposalTypeCard({
    required ProposalType type,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF).withOpacity(0.2) : const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF6C63FF), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF6C63FF)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title (common for all types)
        TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Proposal Title',
            labelStyle: TextStyle(color: Colors.white70),
            hintText: 'Enter a clear, concise title',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Type-specific fields
        if (_selectedType == ProposalType.feeChange) ...[
          TextField(
            controller: _newFeeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'New Platform Fee (%)',
              labelStyle: TextStyle(color: Colors.white70),
              hintText: 'e.g., 2.5 for 2.5%',
              hintStyle: TextStyle(color: Colors.white30),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF6C63FF)),
              ),
              helperText: 'Current fee: 2.5%',
              helperStyle: TextStyle(color: Colors.white60),
            ),
          ),
        ] else if (_selectedType == ProposalType.custom) ...[
          TextField(
            controller: _customTargetController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Target Contract Address',
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
          const SizedBox(height: 16),
          TextField(
            controller: _customCalldataController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Calldata (hex)',
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
        ],

        const SizedBox(height: 16),

        // Description (common for all types)
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Detailed Description',
            labelStyle: TextStyle(color: Colors.white70),
            hintText: 'Explain why this proposal should be approved...',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review your proposal before submitting:',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 16),

        _buildReviewItem('Type', _getProposalTypeName()),
        _buildReviewItem('Title', _titleController.text),

        if (_selectedType == ProposalType.feeChange)
          _buildReviewItem('New Fee', '${_newFeeController.text}%'),

        if (_selectedType == ProposalType.custom) ...[
          _buildReviewItem('Target', _customTargetController.text),
          _buildReviewItem('Calldata', _customCalldataController.text),
        ],

        _buildReviewItem('Description', _descriptionController.text),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What happens next:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildTimelineItem('1', 'Proposal submitted to blockchain'),
              _buildTimelineItem('2', 'Voting delay period (~1 day)'),
              _buildTimelineItem('3', 'Voting period (~7 days)'),
              _buildTimelineItem('4', 'If succeeded, can be queued'),
              _buildTimelineItem('5', 'After timelock (~48 hours), can be executed'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? 'Not provided' : value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getProposalTypeName() {
    switch (_selectedType) {
      case ProposalType.feeChange:
        return 'Marketplace Fee Change';
      case ProposalType.treasuryAction:
        return 'Treasury Action';
      case ProposalType.pauseContract:
        return 'Pause/Unpause Contract';
      case ProposalType.custom:
        return 'Custom Action';
    }
  }

  void _onStepContinue() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _submitProposal();
    }
  }

  Future<void> _submitProposal() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final governanceService = ref.read(governanceServiceProvider);

      // Check voting power before attempting to create proposal
      final walletState = ref.read(walletProvider);
      if (walletState.address == null) {
        throw Exception('Wallet not connected');
      }
      final votingPower = await governanceService.getVotingPower(walletState.address!);
      if (votingPower == BigInt.zero) {
        throw Exception(
          'You need voting power to create proposals. '
          'Delegate VLTC tokens to yourself first in the Delegation tab.'
        );
      }

      // Build proposal based on type
      late List<EthereumAddress> targets;
      late List<BigInt> values;
      late List<Uint8List> calldatas;
      late String description;

      if (_selectedType == ProposalType.feeChange) {
        final newFee = double.parse(_newFeeController.text);
        final newFeeBasisPoints = BigInt.from((newFee * 100).toInt());

        targets = [EthereumAddress.fromHex(ContractAddresses.marketplace)];
        values = [BigInt.zero];
        calldatas = [governanceService.createSetPlatformFeeCalldata(newFeeBasisPoints)];
        description = '${_titleController.text}\n\n${_descriptionController.text}';
      } else if (_selectedType == ProposalType.treasuryAction) {
        // Treasury action - simple governance action without specific contract call
        // For MVP, this creates a proposal for discussion/signaling
        targets = [EthereumAddress.fromHex(ContractAddresses.daoGovernor)];
        values = [BigInt.zero];
        // Empty calldata for signaling proposal
        calldatas = [Uint8List(0)];
        description = '[Treasury Action]\n\n${_titleController.text}\n\n${_descriptionController.text}';
      } else if (_selectedType == ProposalType.pauseContract) {
        // Pause contract - targets ContentRegistry or Marketplace
        targets = [EthereumAddress.fromHex(ContractAddresses.contentRegistry)];
        values = [BigInt.zero];
        // pause() function selector: 0x8456cb59
        calldatas = [Uint8List.fromList([0x84, 0x56, 0xcb, 0x59])];
        description = '[Pause Contract]\n\n${_titleController.text}\n\n${_descriptionController.text}';
      } else if (_selectedType == ProposalType.custom) {
        targets = [EthereumAddress.fromHex(_customTargetController.text)];
        values = [BigInt.zero];
        calldatas = [_hexToBytes(_customCalldataController.text)];
        description = '${_titleController.text}\n\n${_descriptionController.text}';
      } else {
        throw Exception('Unknown proposal type');
      }

      final proposalId = await governanceService.createProposal(
        targets: targets,
        values: values,
        calldatas: calldatas,
        description: description,
      );

      if (mounted) {
        Navigator.of(context).pop(proposalId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proposal created successfully! ID: $proposalId'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create proposal: ${e.toString()}';
        _isSubmitting = false;
      });
    }
  }

  Uint8List _hexToBytes(String hex) {
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    }
    return Uint8List.fromList(
      List.generate(
        hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );
  }
}
