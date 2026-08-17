import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/receipt_service.dart';
import 'firebase_providers.dart';

class ReceiptState {
  final bool isUploading;
  final double uploadProgress;
  final String? error;
  final String? receiptUrl;

  const ReceiptState({
    this.isUploading = false,
    this.uploadProgress = 0,
    this.error,
    this.receiptUrl,
  });

  ReceiptState copyWith({
    bool? isUploading,
    double? uploadProgress,
    String? error,
    String? receiptUrl,
  }) {
    return ReceiptState(
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }
}

class ReceiptNotifier extends StateNotifier<ReceiptState> {
  final ReceiptService _receiptService;

  ReceiptNotifier(this._receiptService) : super(const ReceiptState());

  void clearError() {
    state = state.copyWith(error: null);
  }

  void clearReceiptUrl() {
    state = const ReceiptState();
  }

  Future<XFile?> pickFromCamera() async {
    try {
      return await _receiptService.pickFromCamera();
    } catch (e) {
      state = state.copyWith(error: 'Failed to open camera: $e');
      return null;
    }
  }

  Future<XFile?> pickFromGallery() async {
    try {
      return await _receiptService.pickFromGallery();
    } catch (e) {
      state = state.copyWith(error: 'Failed to open gallery: $e');
      return null;
    }
  }

  Future<String?> uploadReceipt({
    required XFile image,
    required String tripId,
    required String expenseId,
  }) async {
    state = state.copyWith(isUploading: true, uploadProgress: 0, error: null);
    try {
      final url = await _receiptService.uploadReceipt(
        image: image,
        tripId: tripId,
        expenseId: expenseId,
      );
      state = state.copyWith(
        isUploading: false,
        uploadProgress: 1,
        receiptUrl: url,
      );
      return url;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        uploadProgress: 0,
        error: 'Upload failed: $e',
      );
      return null;
    }
  }

  Future<void> deleteReceipt({
    required String tripId,
    required String expenseId,
  }) async {
    await _receiptService.deleteReceipt(
      tripId: tripId,
      expenseId: expenseId,
    );
    state = state.copyWith(receiptUrl: null);
  }
}

final receiptServiceProvider = Provider<ReceiptService>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return ReceiptService(storageService: storageService);
});

final receiptProvider =
    StateNotifierProvider<ReceiptNotifier, ReceiptState>((ref) {
  final receiptService = ref.watch(receiptServiceProvider);
  return ReceiptNotifier(receiptService);
});
