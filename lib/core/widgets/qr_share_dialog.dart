import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRShareDialog extends StatelessWidget {
  final String tripName;
  final String inviteCode;

  const QRShareDialog({
    super.key,
    required this.tripName,
    required this.inviteCode,
  });

  static Future<void> show(
    BuildContext context, {
    required String tripName,
    required String inviteCode,
  }) {
    return showDialog(
      context: context,
      builder: (_) => QRShareDialog(
        tripName: tripName,
        inviteCode: inviteCode,
      ),
    );
  }

  void _share(BuildContext context) {
    final text = 'Join my trip "$tripName" using invite code: $inviteCode';
    Share.share(text, subject: 'Trip Invite: $tripName');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.qr_code_rounded,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share Trip QR',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tripName,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: inviteCode,
                version: QrVersions.auto,
                size: 200,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: colorScheme.onSurface,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.vpn_key_rounded,
                      size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    inviteCode,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      // Copy to clipboard is handled by system share
                    },
                    child: Icon(Icons.copy_rounded,
                        size: 16, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _share(context),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share Invite'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
