import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/marketplace_provider.dart';
import '../../core/services/marketplace_service.dart';

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage> {
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load listings when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(marketplaceProvider.notifier).loadListings();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadListings() async {
    await ref.read(marketplaceProvider.notifier).loadListings();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        ref.read(marketplaceProvider.notifier).setSearchQuery('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final marketplaceState = ref.watch(marketplaceProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search listings...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  ref.read(marketplaceProvider.notifier).setSearchQuery(value);
                },
              )
            : const Text('Marketplace'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Active filters chips
          if (marketplaceState.hasActiveFilters)
            _buildActiveFiltersChips(marketplaceState),

          // Main content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadListings,
              child: marketplaceState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : marketplaceState.error != null
                      ? _buildErrorState(marketplaceState.error!)
                      : marketplaceState.filteredListings.isEmpty
                          ? _buildEmptyState(marketplaceState)
                          : _buildListingsGrid(marketplaceState.filteredListings),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersChips(MarketplaceState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (state.selectedCategory.toLowerCase() != 'all')
            Chip(
              label: Text(state.selectedCategory),
              onDeleted: () {
                ref.read(marketplaceProvider.notifier).setCategory('all');
              },
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (state.searchQuery.isNotEmpty)
            Chip(
              label: Text('Search: "${state.searchQuery}"'),
              onDeleted: () {
                _searchController.clear();
                ref.read(marketplaceProvider.notifier).setSearchQuery('');
              },
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (state.showFreeOnly)
            Chip(
              label: const Text('Free Only'),
              onDeleted: () {
                ref.read(marketplaceProvider.notifier).toggleFreeOnly();
              },
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          if (state.showPaidOnly)
            Chip(
              label: const Text('Paid Only'),
              onDeleted: () {
                ref.read(marketplaceProvider.notifier).togglePaidOnly();
              },
              deleteIcon: const Icon(Icons.close, size: 18),
            ),
          TextButton.icon(
            onPressed: () {
              _searchController.clear();
              ref.read(marketplaceProvider.notifier).clearFilters();
            },
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Listings',
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
            onPressed: _loadListings,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(MarketplaceState state) {
    final hasFilters = state.hasActiveFilters;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off : Icons.store_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No listings found'
                : 'No listings available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              hasFilters
                  ? 'Try adjusting your filters or search query'
                  : 'Check back later for new content',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                ref.read(marketplaceProvider.notifier).clearFilters();
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All Filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListingsGrid(List<MarketplaceListing> listings) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final listing = listings[index];
        return _ListingCard(
          listing: listing,
          onTap: () => _showListingDetails(listing),
        );
      },
    );
  }

  void _showFilterSheet() {
    final state = ref.read(marketplaceProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    ref.read(marketplaceProvider.notifier).clearFilters();
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Category Filter
            Text(
              'Category',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: state.selectedCategory == 'all',
                  onSelected: () {
                    ref.read(marketplaceProvider.notifier).setCategory('all');
                  },
                ),
                _FilterChip(
                  label: 'Journal',
                  selected: state.selectedCategory == 'journal',
                  onSelected: () {
                    ref.read(marketplaceProvider.notifier).setCategory('journal');
                  },
                ),
                _FilterChip(
                  label: 'Music',
                  selected: state.selectedCategory == 'music',
                  onSelected: () {
                    ref.read(marketplaceProvider.notifier).setCategory('music');
                  },
                ),
                _FilterChip(
                  label: 'Art',
                  selected: state.selectedCategory == 'art',
                  onSelected: () {
                    ref.read(marketplaceProvider.notifier).setCategory('art');
                  },
                ),
                _FilterChip(
                  label: 'Video',
                  selected: state.selectedCategory == 'video',
                  onSelected: () {
                    ref.read(marketplaceProvider.notifier).setCategory('video');
                  },
                ),
                _FilterChip(
                  label: 'Document',
                  selected: state.selectedCategory == 'document',
                  onSelected: () {
                    ref.read(marketplaceProvider.notifier).setCategory('document');
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Price Filter
            Text(
              'Price',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'Free Only',
                  icon: Icons.money_off,
                  selected: state.showFreeOnly,
                  onSelected: () {
                    ref.read(marketplaceProvider.notifier).toggleFreeOnly();
                  },
                ),
                _FilterChip(
                  label: 'Paid Only',
                  icon: Icons.attach_money,
                  selected: state.showPaidOnly,
                  onSelected: () {
                    ref.read(marketplaceProvider.notifier).togglePaidOnly();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showListingDetails(MarketplaceListing listing) {
    ref.read(marketplaceProvider.notifier).selectListing(listing);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ListingDetailsPage(listing: listing),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final MarketplaceListing listing;
  final VoidCallback onTap;

  const _ListingCard({
    required this.listing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with gradient background
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _getCategoryGradient(listing.category),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: listing.thumbnailUrl != null
                    ? Image.network(
                        listing.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildCategoryIcon(listing.category);
                        },
                      )
                    : _buildCategoryIcon(listing.category),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  if (listing.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        listing.category!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    listing.title ?? 'Content #${listing.contentId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${listing.priceInVLTC.toStringAsFixed(2)} VLTC',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.sellerShort,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'journal':
      case 'poetry':
        return Icons.article_outlined;
      case 'music':
        return Icons.music_note_outlined;
      case 'art':
        return Icons.palette_outlined;
      case 'video':
        return Icons.video_library_outlined;
      case 'document':
        return Icons.description_outlined;
      default:
        return Icons.image_outlined;
    }
  }

  List<Color> _getCategoryGradient(String? category) {
    switch (category?.toLowerCase()) {
      case 'journal':
      case 'poetry':
        return [Colors.purple[300]!, Colors.purple[600]!];
      case 'music':
        return [Colors.pink[300]!, Colors.pink[600]!];
      case 'art':
        return [Colors.orange[300]!, Colors.orange[600]!];
      case 'video':
        return [Colors.red[300]!, Colors.red[600]!];
      case 'document':
        return [Colors.blue[300]!, Colors.blue[600]!];
      default:
        return [Colors.grey[300]!, Colors.grey[500]!];
    }
  }

  Widget _buildCategoryIcon(String? category) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getCategoryIcon(category),
            size: 48,
            color: Colors.white.withOpacity(0.9),
          ),
          const SizedBox(height: 8),
          Text(
            category?.toUpperCase() ?? 'CONTENT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

// Listing Details Page
class ListingDetailsPage extends ConsumerWidget {
  final MarketplaceListing listing;

  const ListingDetailsPage({super.key, required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketplaceState = ref.watch(marketplaceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing Details'),
      ),
      body: marketplaceState.isPurchasing
          ? _buildPurchaseProgress(marketplaceState)
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview Image
                  Container(
                    width: double.infinity,
                    height: 300,
                    color: Colors.grey[200],
                    child: listing.thumbnailUrl != null
                        ? Image.network(
                            listing.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                _getCategoryIcon(),
                                size: 80,
                                color: Colors.grey[400],
                              );
                            },
                          )
                        : Icon(
                            _getCategoryIcon(),
                            size: 80,
                            color: Colors.grey[400],
                          ),
                  ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category
                  if (listing.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        listing.category!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    listing.title ?? 'Content #${listing.contentId}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // Seller
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        listing.sellerShort,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Listing type
                  Row(
                    children: [
                      const Icon(Icons.label_outline, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        listing.listingTypeString,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Price Card
                  Card(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Price',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${listing.priceInVLTC.toStringAsFixed(2)} VLTC',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6C63FF),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              _showPurchaseDialog(context, ref);
                            },
                            icon: const Icon(Icons.shopping_cart),
                            label: const Text('Purchase'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing.description ?? 'No description available',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Details
                  Text(
                    'Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Content ID', listing.contentId.toString()),
                  _buildDetailRow('Listing ID', listing.listingId.toString()),
                  _buildDetailRow('Type', listing.listingTypeString),
                  if (marketplaceState.purchaseError != null)
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
                                marketplaceState.purchaseError!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (listing.category?.toLowerCase()) {
      case 'journal':
        return Icons.article_outlined;
      case 'music':
        return Icons.music_note_outlined;
      case 'art':
        return Icons.palette_outlined;
      case 'video':
        return Icons.video_library_outlined;
      case 'document':
        return Icons.description_outlined;
      default:
        return Icons.image_outlined;
    }
  }

  Widget _buildPurchaseProgress(MarketplaceState state) {
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
              Text(
                state.currentStep ?? 'Processing...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: state.purchaseProgress,
              ),
              const SizedBox(height: 8),
              Text(
                '${(state.purchaseProgress * 100).toInt()}%',
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

  void _showPurchaseDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Content'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${listing.title ?? "Content #${listing.contentId}"}'),
            const SizedBox(height: 8),
            Text(
              'Price: ${listing.priceInVLTC.toStringAsFixed(2)} VLTC',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
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
                      'This will initiate a blockchain transaction. Make sure you have enough VLTC and ETH for gas.',
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

              // Start purchase
              final success = await ref
                  .read(marketplaceProvider.notifier)
                  .purchaseContent(listing);

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Purchase successful!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Go back to marketplace
                  Navigator.pop(context);
                } else {
                  // Error is shown in the UI already
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ref.read(marketplaceProvider).purchaseError ??
                            'Purchase failed',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
            ),
            child: const Text('Confirm Purchase'),
          ),
        ],
      ),
    );
  }
}
