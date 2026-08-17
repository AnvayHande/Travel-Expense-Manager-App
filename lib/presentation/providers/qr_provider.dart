import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/qr_service.dart';
import '../../core/repositories/trip_repository.dart';

final qrServiceProvider = Provider<QRService>((ref) {
  final repository = ref.watch(tripRepositoryProvider);
  return QRService(tripRepository: repository);
});
