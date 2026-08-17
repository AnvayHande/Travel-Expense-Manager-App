import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/models/trip_model.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../presentation/providers/trip_provider.dart';
import '../../../../presentation/providers/authentication_provider.dart';
import '../../../../presentation/providers/activity_provider.dart';
import '../../../../presentation/providers/qr_provider.dart';

class ScanQRScreen extends ConsumerStatefulWidget {
  const ScanQRScreen({super.key});

  @override
  ConsumerState<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends ConsumerState<ScanQRScreen> {
  MobileScannerController? _scannerController;
  bool _isProcessing = false;
  bool _hasError = false;
  String? _errorMessage;
  TripModel? _foundTrip;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _isProcessing = true;
    _handleScannedCode(rawValue);
  }

  Future<void> _handleScannedCode(String rawValue) async {
    final qrService = ref.read(qrServiceProvider);
    final code = qrService.extractInviteCode(rawValue);

    if (code == null) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Invalid QR code.';
          _isProcessing = false;
        });
      }
      return;
    }

    if (!mounted) return;

    final trip = await qrService.validateInviteCode(code);

    if (mounted) {
      if (trip != null) {
        setState(() {
          _foundTrip = trip;
          _hasError = false;
          _errorMessage = null;
          _isProcessing = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'No trip found with this invite code.';
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _joinTrip() async {
    if (_foundTrip == null) return;

    final user = ref.read(authProvider).user;
    if (user == null) {
      SnackbarHelper.showError(context, 'You must be logged in.');
      return;
    }

    final isAlreadyParticipant =
        _foundTrip!.participants.contains(user.uid);
    if (isAlreadyParticipant) {
      SnackbarHelper.showInfo(context, 'You are already a member of this trip.');
      return;
    }

    setState(() => _isJoining = true);

    final success = await ref
        .read(tripProvider.notifier)
        .joinTrip(_foundTrip!.tripId, user.uid);

    if (mounted) {
      setState(() => _isJoining = false);
      if (success) {
        ref.read(activityServiceProvider).logActivity(
          tripId: _foundTrip!.tripId,
          userId: user.uid,
          userName: user.name,
          actionType: 'participant_joined',
          message: 'joined the trip',
        );
        SnackbarHelper.showSuccess(
            context, 'You have joined the trip successfully!');
        context.goNamed(
          'tripDetails',
          pathParameters: {'tripId': _foundTrip!.tripId},
        );
      } else {
        final error = ref.read(tripProvider).error;
        SnackbarHelper.showError(
            context, error ?? 'Failed to join trip.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Scan QR Code'),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    return Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam_off_rounded,
                                size: 64,
                                color: Colors.white.withValues(alpha: 0.6)),
                            const SizedBox(height: 16),
                            Text(
                              _cameraErrorMessage(error),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                IgnorePointer(
                  child: Container(
                    decoration: ShapeDecoration(
                      shape: _QRScannerOverlay(),
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Point camera at a trip QR code',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_hasError)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: colorScheme.onErrorContainer, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage ?? 'An error occurred.',
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          if (_foundTrip != null) _buildTripPreview(colorScheme),
        ],
      ),
    );
  }

  Widget _buildTripPreview(ColorScheme colorScheme) {
    final trip = _foundTrip!;
    final user = ref.read(authProvider).user;
    final isAlreadyParticipant =
        user != null && trip.participants.contains(user.uid);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.card_travel_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.tripName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (trip.destination != null &&
                        trip.destination!.isNotEmpty)
                      Text(
                        trip.destination!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(colorScheme, Icons.person_outlined,
                  trip.adminName),
              const SizedBox(width: 12),
              _buildInfoChip(colorScheme, Icons.people_outlined,
                  '${trip.participants.length} members'),
              if (trip.startDate != null) ...[
                const SizedBox(width: 12),
                _buildInfoChip(colorScheme, Icons.calendar_today_outlined,
                    DateFormatter.formatDate(trip.startDate!)),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: isAlreadyParticipant
                  ? 'Already a Member'
                  : 'Join Trip',
              icon: isAlreadyParticipant
                  ? Icons.check_circle_outline
                  : Icons.group_add_outlined,
              isLoading: _isJoining,
              onPressed: isAlreadyParticipant ? null : _joinTrip,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
      ColorScheme colorScheme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _cameraErrorMessage(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('permission')) {
      return 'Camera permission denied.\nPlease enable it in settings.';
    }
    if (msg.contains('unavailable')) {
      return 'Camera is not available on this device.';
    }
    return 'Camera error: ${error.toString()}';
  }
}

class _QRScannerOverlay extends ShapeBorder {
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final scanSize = 250.0;
    final left = (rect.width - scanSize) / 2;
    final top = (rect.height - scanSize) / 2;
    final scanRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, scanSize, scanSize),
      const Radius.circular(16),
    );

    return Path()
      ..addRect(rect)
      ..addRRect(scanRect)
      ..fillType = PathFillType.evenOdd;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
