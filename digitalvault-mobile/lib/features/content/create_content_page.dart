import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';  // Disabled - not needed for Week 17
import '../../core/providers/content_provider.dart';
import '../../core/providers/wallet_provider.dart';
import '../../core/contracts/content_registry_contract.dart';
import '../../core/contracts/marketplace_contract.dart';

/// Create Content Page
///
/// Complete end-to-end content upload workflow:
/// 1. File selection (image, video, audio, document)
/// 2. Metadata entry (title, description, category, price)
/// 3. File encryption (AES-256)
/// 4. IPFS upload
/// 5. PRE capsule generation
/// 6. Blockchain registration (ContentRegistry.registerContentWithPRE)
/// 7. Marketplace listing (Marketplace.createListing)
/// 8. Transaction monitoring
class CreateContentPage extends ConsumerStatefulWidget {
  const CreateContentPage({super.key});

  @override
  ConsumerState<CreateContentPage> createState() => _CreateContentPageState();
}

class _CreateContentPageState extends ConsumerState<CreateContentPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  File? _selectedFile;
  ContentCategory _selectedCategory = ContentCategory.art;
  ListingType _selectedListingType = ListingType.fullOwnership;
  int _accessDuration = 0; // For time-based access (seconds)
  int _maxKeys = 0; // For usage-based access

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Reset content provider state when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contentUploadProvider.notifier).reset();
    });
  }

  /// Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (file != null) {
        setState(() {
          _selectedFile = File(file.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  /// Pick any file type - DISABLED (file_picker not available)
  Future<void> _pickFile() async {
    _showError('File picker not available. Please use image picker instead.');
    /*
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = File(result.files.first.path!);
        });
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
    */
  }

  /// Show file picker options
  Future<void> _showFilePickerOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pick from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Pick Any File'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Upload content to blockchain
  Future<void> _uploadContent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedFile == null) {
      _showError('Please select a file');
      return;
    }

    // Check wallet connection
    final walletState = ref.read(walletProvider);
    if (!walletState.isConnected) {
      _showError('Please connect your wallet first');
      return;
    }

    // Parse price
    final priceVltc = int.tryParse(_priceController.text.trim()) ?? 0;

    // Start upload
    final contentId = await ref.read(contentUploadProvider.notifier).uploadContent(
          filePath: _selectedFile!.path,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          priceVltc: priceVltc,
          listingType: _selectedListingType,
          accessDuration: _accessDuration,
          maxKeys: _maxKeys,
        );

    if (mounted) {
      if (contentId != null) {
        // Success
        _showSuccess('Content uploaded successfully! ID: $contentId');

        // Clear form
        setState(() {
          _selectedFile = null;
          _titleController.clear();
          _descriptionController.clear();
          _priceController.clear();
          _selectedCategory = ContentCategory.art;
          _selectedListingType = ListingType.fullOwnership;
          _accessDuration = 0;
          _maxKeys = 0;
        });

        // Reset provider state
        ref.read(contentUploadProvider.notifier).reset();
      } else {
        // Error is already in state
        final uploadState = ref.read(contentUploadProvider);
        if (uploadState.error != null) {
          _showError(uploadState.error!);
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getFileName() {
    if (_selectedFile == null) return '';
    return _selectedFile!.path.split('/').last;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(contentUploadProvider);
    final walletState = ref.watch(walletProvider);

    final isLoading = uploadState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Content'),
        actions: [
          if (!isLoading)
            TextButton.icon(
              onPressed: _selectedFile != null ? _uploadContent : null,
              icon: const Icon(Icons.publish),
              label: const Text('Publish'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6C63FF),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wallet Status
              if (!walletState.isConnected)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connect your wallet to publish content',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/wallet'),
                        child: const Text('Connect'),
                      ),
                    ],
                  ),
                ),

              // File Picker
              GestureDetector(
                onTap: isLoading ? null : _showFilePickerOptions,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedFile != null
                          ? const Color(0xFF6C63FF)
                          : Colors.grey[300]!,
                      width: _selectedFile != null ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: _selectedFile != null
                      ? Stack(
                          children: [
                            // Preview (for images)
                            if (_selectedFile!.path.toLowerCase().endsWith('.jpg') ||
                                _selectedFile!.path.toLowerCase().endsWith('.jpeg') ||
                                _selectedFile!.path.toLowerCase().endsWith('.png'))
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _selectedFile!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              )
                            else
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.insert_drive_file,
                                      size: 64,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _getFileName(),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            // Remove button
                            if (!isLoading)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  onPressed: () => setState(() => _selectedFile = null),
                                  icon: const Icon(Icons.close),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to select file',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Images, videos, audio, documents',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              TextFormField(
                controller: _titleController,
                enabled: !isLoading,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Enter content title',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                enabled: !isLoading,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Describe your content',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.description),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<ContentCategory>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ContentCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(_formatCategory(category)),
                  );
                }).toList(),
                onChanged: isLoading ? null : (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Price
              TextFormField(
                controller: _priceController,
                enabled: !isLoading,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Price (VLTC)',
                  hintText: '100',
                  helperText: 'Enter 0 for free content',
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixText: 'VLTC',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final price = int.tryParse(value.trim());
                    if (price == null || price < 0) {
                      return 'Please enter a valid price';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Listing Type
              DropdownButtonFormField<ListingType>(
                value: _selectedListingType,
                decoration: InputDecoration(
                  labelText: 'Listing Type *',
                  prefixIcon: const Icon(Icons.sell),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ListingType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_formatListingType(type)),
                  );
                }).toList(),
                onChanged: isLoading ? null : (value) {
                  if (value != null) {
                    setState(() => _selectedListingType = value);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Upload Progress
              if (isLoading) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Current step
                      Text(
                        uploadState.currentStep ?? 'Processing...',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6C63FF),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Progress bar
                      LinearProgressIndicator(
                        value: uploadState.uploadProgress,
                        backgroundColor: Colors.grey[200],
                        color: const Color(0xFF6C63FF),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),

                      // Percentage
                      Text(
                        '${(uploadState.uploadProgress * 100).toInt()}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),

                      // Status indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatusChip(
                            'Encrypt',
                            uploadState.uploadProgress > 0,
                          ),
                          _buildStatusChip(
                            'Upload',
                            uploadState.uploadProgress > 0.5,
                          ),
                          _buildStatusChip(
                            'Register',
                            uploadState.uploadProgress > 0.7,
                          ),
                          _buildStatusChip(
                            'List',
                            uploadState.uploadProgress >= 1.0,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Error Message
              if (uploadState.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          uploadState.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Info Card
              Card(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.security,
                            color: Color(0xFF6C63FF),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Security & Privacy',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• AES-256 encryption before upload\n'
                        '• Proxy Re-Encryption (PRE) for secure sharing\n'
                        '• Immutable blockchain ownership\n'
                        '• Only authorized buyers can decrypt',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isComplete) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: isComplete ? Colors.white : Colors.grey[600],
          fontSize: 12,
        ),
      ),
      backgroundColor: isComplete ? const Color(0xFF6C63FF) : Colors.grey[200],
      avatar: Icon(
        isComplete ? Icons.check_circle : Icons.circle_outlined,
        size: 16,
        color: isComplete ? Colors.white : Colors.grey[600],
      ),
    );
  }

  String _formatCategory(ContentCategory category) {
    switch (category) {
      case ContentCategory.journal:
        return 'Poetry';
      case ContentCategory.music:
        return 'Music';
      case ContentCategory.art:
        return 'Art';
      case ContentCategory.video:
        return 'Video';
      case ContentCategory.document:
        return 'Document';
    }
  }

  String _formatListingType(ListingType type) {
    switch (type) {
      case ListingType.fullOwnership:
        return 'Full Ownership';
      case ListingType.timeAccess:
        return 'Time-Based Access';
      case ListingType.usageAccess:
        return 'Usage-Based Access';
    }
  }
}
