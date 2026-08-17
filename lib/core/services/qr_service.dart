import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';

class QRService {
  final TripRepository _tripRepository;

  QRService({required TripRepository tripRepository})
      : _tripRepository = tripRepository;

  String generateQRData(String inviteCode) {
    return inviteCode;
  }

  String? extractInviteCode(String qrData) {
    final code = qrData.trim().toUpperCase();
    if (code.isEmpty) return null;
    return code;
  }

  Future<TripModel?> validateInviteCode(String code) async {
    return await _tripRepository.getTripByInviteCode(code);
  }
}
