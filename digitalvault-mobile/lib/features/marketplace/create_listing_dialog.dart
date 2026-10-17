import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/content_browse_service.dart';
import '../../core/contracts/marketplace_contract.dart';
import '../../core/contracts/content_registry_contract.dart';
import '../../core/providers/marketplace_provider.dart';

/// Create Listing Dialog
///
/// Dialog for listing content for sale on the marketplace.
/// Allows user to set price and listing type.
class CreateListingDialog extends ConsumerStatefulWidget {
  final ContentItem content;

  const CreateListingDialog({
    super.key,
    required this.content,
  });

  @override
  ConsumerState<CreateListingDialog> createState() => _CreateListingDialogState();
}

class _CreateListingDialogState extends ConsumerState<CreateListingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();

  ListingType _selectedType = ListingType.fullOwnership;
  bool _isCreating = false;
  String? _error;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.sell,
              color: Color(0xFF6C63FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'List for Sale',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Content info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(widget.content.category),
                      color: const Color(0xFF6C63FF),
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.content.title ?? 'Untitled',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.content.formattedFileSize,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Listing type
              const Text(
                'Listing Type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    RadioListTile<ListingType>(
                      value: ListingType.fullOwnership,
                      groupValue: _selectedType,
                      onChanged: _isCreating ? null : (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                      title: const Text(
                        'Full Ownership',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        'Transfer complete ownership of content',
                        style: TextStyle(fontSize: 12),
                      ),
                      activeColor: const Color(0xFF6C63FF),
                    ),
                    Divider(height: 1, color: Colors.grey[300]),
                    RadioListTile<ListingType>(
                      value: ListingType.timeAccess,
                      groupValue: _selectedType,
                      onChanged: _isCreating ? null : (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                      title: Row(
                        children: [
                          const Text(
                            'Time-Based Access',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'COMING SOON',
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: const Text(
                        'Grant temporary access for a duration',
                        style: TextStyle(fontSize: 12),
                      ),
                      activeColor: const Color(0xFF6C63FF),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Price input
              const Text(
                'Price in VLTC',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                enabled: !_isCreating,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  hintText: 'Enter price (e.g., 100)',
                  prefixIcon: const Icon(Icons.monetization_on),
                  suffixText: 'VLTC',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: _isCreating ? Colors.grey[100] : null,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Price must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Platform fee: 2.5% • You will receive: ${_calculateSellerAmount()} VLTC',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createListing,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Create Listing'),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(ContentCategory category) {
    switch (category) {
      case ContentCategory.journal:
        return Icons.article;
      case ContentCategory.music:
        return Icons.music_note;
      case ContentCategory.art:
        return Icons.image;
      case ContentCategory.video:
        return Icons.video_library;
      case ContentCategory.document:
        return Icons.description;
    }
  }

  String _calculateSellerAmount() {
    final priceText = _priceController.text;
    if (priceText.isEmpty) return '0.00';

    final price = double.tryParse(priceText);
    if (price == null) return '0.00';

    final fee = price * 0.025; // 2.5%
    final sellerAmount = price - fee;
    return sellerAmount.toStringAsFixed(2);
  }

  Future<void> _createListing() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Time-based access not yet implemented
    if (_selectedType == ListingType.timeAccess) {
      setState(() {
        _error = 'Time-based access is coming soon. Please select Full Ownership.';
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      // Get price in VLTC wei (18 decimals)
      final priceDouble = double.parse(_priceController.text);
      final priceWei = BigInt.from((priceDouble * 1e18).toInt());

      // Import marketplace service
      final marketplaceService = ref.read(marketplaceServiceProvider);

      // Create listing
      final listingId = await marketplaceService.createListing(
        contentId: widget.content.id,
        price: priceWei,
        listingType: _selectedType,
        accessDuration: BigInt.zero, // 0 for full ownership
        maxKeys: BigInt.zero,         // 0 for full ownership
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Content listed! Listing ID: $listingId',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Close dialog with success
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _error = _parseError(e.toString());
        _isCreating = false;
      });
    }
  }

  String _parseError(String error) {
    if (error.contains('insufficient funds')) {
      return 'Insufficient ETH for gas fees';
    } else if (error.contains('user rejected')) {
      return 'Transaction was rejected';
    } else if (error.contains('not own')) {
      return 'You do not own this content';
    } else if (error.contains('already listed')) {
      return 'Content is already listed';
    } else {
      return 'Failed to create listing: ${error.substring(0, error.length > 100 ? 100 : error.length)}';
    }
  }
}

