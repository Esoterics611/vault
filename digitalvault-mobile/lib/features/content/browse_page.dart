import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/content_provider.dart';
import '../../core/services/content_browse_service.dart';
import '../../core/contracts/content_registry_contract.dart';
import 'content_detail_page.dart';

/// Browse Page
///
/// Displays a grid of all available content in the DigitalVault marketplace.
class BrowsePage extends ConsumerStatefulWidget {
  const BrowsePage({super.key});

  @override
  ConsumerState<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends ConsumerState<BrowsePage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load content when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contentBrowseProvider.notifier).loadContent();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentBrowseProvider);
    final filteredItems = ref.watch(filteredContentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Content'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search content...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(contentBrowseProvider.notifier)
                              .setSearchQuery('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                ref.read(contentBrowseProvider.notifier).setSearchQuery(value);
              },
            ),
          ),

          // Filter Chips
          if (state.selectedCategory != null ||
              state.showFreeOnly ||
              state.showPaidOnly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8,
                children: [
                  if (state.selectedCategory != null)
                    FilterChip(
                      label: Text(state.selectedCategory!.name.toUpperCase()),
                      onSelected: (_) {
                        ref
                            .read(contentBrowseProvider.notifier)
                            .setCategory(null);
                      },
                      selected: true,
                    ),
                  if (state.showFreeOnly)
                    FilterChip(
                      label: const Text('FREE ONLY'),
                      onSelected: (_) {
                        ref
                            .read(contentBrowseProvider.notifier)
                            .toggleFreeOnly();
                      },
                      selected: true,
                    ),
                  if (state.showPaidOnly)
                    FilterChip(
                      label: const Text('PAID ONLY'),
                      onSelected: (_) {
                        ref
                            .read(contentBrowseProvider.notifier)
                            .togglePaidOnly();
                      },
                      selected: true,
                    ),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(contentBrowseProvider.notifier).clearFilters();
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear All'),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Content Grid
          Expanded(
            child: _buildContentGrid(state, filteredItems),
          ),
        ],
      ),
    );
  }

  Widget _buildContentGrid(
      ContentBrowseState state, List<ContentItem> items) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading content...'),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: ${state.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(contentBrowseProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              state.searchQuery.isNotEmpty
                  ? 'No content found matching "${state.searchQuery}"'
                  : 'No content available yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Be the first to upload content!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(contentBrowseProvider.notifier).refresh();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return ContentCard(item: items[index]);
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const FilterBottomSheet(),
    );
  }
}

/// Content Card Widget
///
/// Displays a single content item in the grid.
class ContentCard extends ConsumerWidget {
  final ContentItem item;

  const ContentCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContentDetailPage(contentId: item.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _getCategoryGradient(item.category),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getCategoryIcon(item.category),
                    size: 48,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ),

            // Content Info
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item.title ?? 'Untitled',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Category Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(item.category),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.category.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // File Size
                      Text(
                        item.formattedFileSize,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.formattedPrice,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: item.isFree ? Colors.green : Colors.blue,
                        ),
                      ),
                      if (!item.isFree)
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
        return Icons.videocam;
      case ContentCategory.document:
        return Icons.description;
    }
  }

  Color _getCategoryColor(ContentCategory category) {
    switch (category) {
      case ContentCategory.journal:
        return Colors.purple;
      case ContentCategory.music:
        return Colors.pink;
      case ContentCategory.art:
        return Colors.orange;
      case ContentCategory.video:
        return Colors.red;
      case ContentCategory.document:
        return Colors.blue;
    }
  }

  List<Color> _getCategoryGradient(ContentCategory category) {
    switch (category) {
      case ContentCategory.journal:
        return [Colors.purple[300]!, Colors.purple[600]!];
      case ContentCategory.music:
        return [Colors.pink[300]!, Colors.pink[600]!];
      case ContentCategory.art:
        return [Colors.orange[300]!, Colors.orange[600]!];
      case ContentCategory.video:
        return [Colors.red[300]!, Colors.red[600]!];
      case ContentCategory.document:
        return [Colors.blue[300]!, Colors.blue[600]!];
    }
  }
}

/// Filter Bottom Sheet
///
/// Allows users to filter content by category and price.
class FilterBottomSheet extends ConsumerWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contentBrowseProvider);
    final categoryCounts = ref.watch(categoriesWithCountsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Content',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(contentBrowseProvider.notifier).clearFilters();
                  Navigator.pop(context);
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Category Filter
          const Text(
            'Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ContentCategory.values.map((category) {
              final count = categoryCounts[category] ?? 0;
              final isSelected = state.selectedCategory == category;

              return FilterChip(
                label: Text(
                  '${category.name.toUpperCase()} ($count)',
                ),
                selected: isSelected,
                onSelected: (selected) {
                  ref
                      .read(contentBrowseProvider.notifier)
                      .setCategory(selected ? category : null);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Price Filter
          const Text(
            'Price',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('FREE ONLY'),
                selected: state.showFreeOnly,
                onSelected: (_) {
                  ref.read(contentBrowseProvider.notifier).toggleFreeOnly();
                },
              ),
              FilterChip(
                label: const Text('PAID ONLY'),
                selected: state.showPaidOnly,
                onSelected: (_) {
                  ref.read(contentBrowseProvider.notifier).togglePaidOnly();
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}
