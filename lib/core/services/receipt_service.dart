import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'storage_service.dart';

class ReceiptService {
  final StorageService _storageService;
  final ImagePicker _picker;

  ReceiptService({
    required this._storageService,
    ImagePicker? picker,
  })  : _picker = picker ?? ImagePicker();

  Future<XFile?> pickFromCamera() async {
    return _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
  }

  Future<XFile?> pickFromGallery() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
  }

  Future<String> uploadReceipt({
    required XFile image,
    required String tripId,
    required String expenseId,
  }) async {
    final path = 'receipts/$tripId/$expenseId.jpg';
    final file = File(image.path);
    final url = await _storageService.uploadFile(
      path: path,
      file: file,
    );
    return url;
  }

  Future<void> deleteReceipt({
    required String tripId,
    required String expenseId,
  }) async {
    try {
      await _storageService.deleteFile('receipts/$tripId/$expenseId.jpg');
    } catch (_) {
    }
  }
}
