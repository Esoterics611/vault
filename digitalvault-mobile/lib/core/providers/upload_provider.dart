import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web3dart/web3dart.dart';
import '../services/content_upload_service.dart';
import '../services/web3_service.dart';
import 'wallet_provider.dart';

/// Upload State
class UploadState {
  final bool isUploading;
  final UploadStep? currentStep;
  final double progress; // 0.0 to 1.0
  final String? error;
  final UploadResult? result;

  /// Selected file info
  final File? selectedFile;
  final String? filePreview; // Path for preview
  final int? fileSize;

  /// Form data
  final String title;
  final String description;
  final String contentType;
  final String priceInVLTC;

  const UploadState({
    this.isUploading = false,
    this.currentStep,
    this.progress = 0.0,
    this.error,
    this.result,
    this.selectedFile,
    this.filePreview,
    this.fileSize,
    this.title = '',
    this.description = '',
    this.contentType = 'image',
    this.priceInVLTC = '0',
  });

  UploadState copyWith({
    bool? isUploading,
    UploadStep? currentStep,
    double? progress,
    String? error,
    UploadResult? result,
    File? selectedFile,
    String? filePreview,
    int? fileSize,
    String? title,
    String? description,
    String? contentType,
    String? priceInVLTC,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      currentStep: currentStep ?? this.currentStep,
      progress: progress ?? this.progress,
      error: error,
      result: result,
      selectedFile: selectedFile ?? this.selectedFile,
      filePreview: filePreview ?? this.filePreview,
      fileSize: fileSize ?? this.fileSize,
      title: title ?? this.title,
      description: description ?? this.description,
      contentType: contentType ?? this.contentType,
      priceInVLTC: priceInVLTC ?? this.priceInVLTC,
    );
  }

  bool get hasFile => selectedFile != null;
  bool get canUpload =>
      hasFile && title.isNotEmpty && !isUploading;

  String get fileSizeFormatted {
    if (fileSize == null) return '';
    final mb = fileSize! / (1024 * 1024);
    if (mb >= 1) {
      return '${mb.toStringAsFixed(2)} MB';
    }
    final kb = fileSize! / 1024;
    return '${kb.toStringAsFixed(2)} KB';
  }

  int get progressPercent => (progress * 100).toInt();
}

/// Upload Notifier
class UploadNotifier extends StateNotifier<UploadState> {
  final ContentUploadService _uploadService;
  final Web3Service _web3Service;
  final Ref _ref;

  UploadNotifier(
    this._uploadService,
    this._web3Service,
    this._ref,
  ) : super(const UploadState());

  /// Select file from gallery/camera
  void selectFile(File file, {String? preview}) {
    final fileSize = file.lengthSync();
    state = state.copyWith(
      selectedFile: file,
      filePreview: preview ?? file.path,
      fileSize: fileSize,
      error: null,
    );
  }

  /// Clear selected file
  void clearFile() {
    state = state.copyWith(
      selectedFile: null,
      filePreview: null,
      fileSize: null,
      error: null,
    );
  }

  /// Update title
  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  /// Update description
  void setDescription(String description) {
    state = state.copyWith(description: description);
  }

  /// Update content type
  void setContentType(String contentType) {
    state = state.copyWith(contentType: contentType);
  }

  /// Update price
  void setPrice(String price) {
    state = state.copyWith(priceInVLTC: price);
  }

  /// Upload content
  Future<bool> uploadContent() async {
    // Validation
    if (!state.canUpload) {
      state = state.copyWith(error: 'Please select a file and enter a title');
      return false;
    }

    // Check wallet connection
    final walletState = _ref.read(walletProvider);
    if (!walletState.isConnected) {
      state = state.copyWith(error: 'Wallet not connected');
      return false;
    }

    state = state.copyWith(
      isUploading: true,
      progress: 0.0,
      error: null,
      result: null,
    );

    try {
      // Parse price
      final price = BigInt.tryParse(state.priceInVLTC) ?? BigInt.zero;
      final priceInWei = price * BigInt.from(10).pow(18); // Convert to wei

      // Create metadata
      final metadata = ContentMetadata(
        title: state.title,
        description: state.description,
        contentType: state.contentType,
        fileSize: state.fileSize!,
        previewUrl: state.filePreview,
      );

      // Upload with progress tracking
      final result = await _uploadService.uploadContent(
        file: state.selectedFile!,
        metadata: metadata,
        priceInVLTC: priceInWei,
        onProgress: (step, progress) {
          state = state.copyWith(
            currentStep: step,
            progress: progress,
          );
        },
      );

      // Success
      state = state.copyWith(
        isUploading: false,
        progress: 1.0,
        result: result,
        error: null,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Reset upload state
  void reset() {
    state = const UploadState();
  }

  /// Reset only upload progress (keep form data)
  void resetProgress() {
    state = state.copyWith(
      isUploading: false,
      currentStep: null,
      progress: 0.0,
      error: null,
      result: null,
    );
  }
}

/// Upload Provider
final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  final web3Service = ref.watch(web3ServiceProvider);
  final uploadService = ContentUploadService(web3Service);

  return UploadNotifier(
    uploadService,
    web3Service,
    ref,
  );
});

// web3ServiceProvider is now imported from wallet_provider.dart
