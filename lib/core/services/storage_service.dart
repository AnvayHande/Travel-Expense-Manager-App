import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../exceptions/app_exceptions.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService() : _storage = FirebaseStorage.instance;

  Reference get ref => _storage.ref();

  Reference refFromPath(String path) => _storage.ref(path);

  Future<String> uploadFile({
    required String path,
    required File file,
    String? fileName,
  }) async {
    try {
      final finalPath = fileName != null ? '$path/$fileName' : path;
      final ref = _storage.ref(finalPath);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e, stackTrace) {
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<String> uploadBytes({
    required String path,
    required List<int> bytes,
  }) async {
    try {
      final ref = _storage.ref(path);
      await ref.putData(Uint8List.fromList(bytes));
      return await ref.getDownloadURL();
    } catch (e, stackTrace) {
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<void> deleteFile(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (e, stackTrace) {
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }

  Future<String> getDownloadUrl(String path) async {
    try {
      return await _storage.ref(path).getDownloadURL();
    } catch (e, stackTrace) {
      throw FirebaseExceptionHandler.handle(e, stackTrace: stackTrace);
    }
  }
}
