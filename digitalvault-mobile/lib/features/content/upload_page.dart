import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/providers/upload_provider.dart';
import '../../core/services/content_upload_service.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final ImagePicker _picker = ImagePicker();

  String _selectedContentType = 'image';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Content'),
        actions: [
          if (uploadState.hasFile)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                ref.read(uploadProvider.notifier).clearFile();
                _titleController.clear();
                _descriptionController.clear();
                _priceController.text = '0';
              },
              tooltip: 'Clear',
            ),
        ],
      ),
      body: uploadState.isUploading
          ? _buildUploadingUI(uploadState)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // File selection area
                    _buildFileSelector(uploadState),
                    const SizedBox(height: 24),

                    // Metadata form (only show if file selected)
                    if (uploadState.hasFile) ...[
                      _buildMetadataForm(uploadState),
                      const SizedBox(height: 24),

                      // Upload button
                      _buildUploadButton(uploadState),
                    ],

                    // Error display
                    if (uploadState.error != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorDisplay(uploadState.error!),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFileSelector(UploadState state) {
    if (state.hasFile) {
      return _buildFilePreview(state);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Select Content to Upload',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose from camera or gallery',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                _buildSourceButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePreview(UploadState state) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          if (state.filePreview != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.file(
                File(state.filePreview!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 64),
                  ),
                ),
              ),
            ),

          // File info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green[600],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'File Selected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.fileSizeFormatted,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => ref.read(uploadProvider.notifier).clearFile(),
                  icon: const Icon(Icons.close),
                  label: const Text('Change'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataForm(UploadState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Content Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),

        // Title
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Title *',
            hintText: 'Enter a catchy title',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.title),
          ),
          maxLength: 100,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Title is required';
            }
            return null;
          },
          onChanged: (value) {
            ref.read(uploadProvider.notifier).setTitle(value);
          },
        ),
        const SizedBox(height: 16),

        // Description
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Describe your content',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.description),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          maxLength: 500,
          onChanged: (value) {
            ref.read(uploadProvider.notifier).setDescription(value);
          },
        ),
        const SizedBox(height: 16),

        // Content Type
        DropdownButtonFormField<String>(
          value: _selectedContentType,
          decoration: const InputDecoration(
            labelText: 'Content Type',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
          items: const [
            DropdownMenuItem(value: 'image', child: Text('Image')),
            DropdownMenuItem(value: 'video', child: Text('Video')),
            DropdownMenuItem(value: 'document', child: Text('Document')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedContentType = value);
              ref.read(uploadProvider.notifier).setContentType(value);
            }
          },
        ),
        const SizedBox(height: 16),

        // Price
        TextFormField(
          controller: _priceController,
          decoration: const InputDecoration(
            labelText: 'Price (VLTC)',
            hintText: '0 for free',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
            helperText: 'Set to 0 for free content',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (BigInt.tryParse(value) == null) {
                return 'Invalid price';
              }
            }
            return null;
          },
          onChanged: (value) {
            ref.read(uploadProvider.notifier).setPrice(value);
          },
        ),
      ],
    );
  }

  Widget _buildUploadButton(UploadState state) {
    return ElevatedButton(
      onPressed: state.canUpload ? _handleUpload : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBackgroundColor: Colors.grey[300],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.upload),
          SizedBox(width: 8),
          Text(
            'Upload Content',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingUI(UploadState state) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress circle
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: state.progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6C63FF),
                      ),
                    ),
                    Text(
                      '${state.progressPercent}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Current step
              Text(
                state.currentStep?.description ?? 'Uploading...',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Progress steps
              _buildProgressSteps(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSteps(UploadState state) {
    final steps = [
      UploadStep.encrypting,
      UploadStep.creatingCapsule,
      UploadStep.uploadingToIPFS,
      UploadStep.storingCapsule,
      UploadStep.registering,
      UploadStep.complete,
    ];

    return Column(
      children: steps.map((step) {
        final isActive = state.currentStep == step;
        final isComplete = state.currentStep != null &&
            state.currentStep!.value > step.value;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                isComplete
                    ? Icons.check_circle
                    : isActive
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                color: isComplete || isActive
                    ? const Color(0xFF6C63FF)
                    : Colors.grey[400],
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.description,
                  style: TextStyle(
                    color: isComplete || isActive
                        ? Colors.black87
                        : Colors.grey[600],
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildErrorDisplay(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload Failed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        ref.read(uploadProvider.notifier).selectFile(file, preview: image.path);

        // Set default content type
        setState(() => _selectedContentType = 'image');
        ref.read(uploadProvider.notifier).setContentType('image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleUpload() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref.read(uploadProvider.notifier).uploadContent();

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back or to content list
        Navigator.pop(context);
      } else {
        // Error is already shown in UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(uploadProvider).error ?? 'Upload failed',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
