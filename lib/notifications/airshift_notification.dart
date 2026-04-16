import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AirShiftNotification extends StatelessWidget {
  final String senderName;
  final String fileName;
  final int fileSize;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const AirShiftNotification({
    super.key,
    required this.senderName,
    required this.fileName,
    required this.fileSize,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AirShiftColors.glassSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AirShiftColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.airplanemode_active, color: AirShiftColors.bluePrimary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Incoming Shift',
                  style: TextStyle(
                    color: AirShiftColors.bluePrimary.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              senderName,
              style: const TextStyle(
                color: AirShiftColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'wants to send $fileName',
              style: TextStyle(
                color: AirShiftColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDecline,
                  child: Text(
                    'Decline',
                    style: TextStyle(color: AirShiftColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AirShiftColors.greenConfirm.withOpacity(0.2),
                    foregroundColor: AirShiftColors.greenConfirm,
                    elevation: 0,
                  ),
                  onPressed: onAccept,
                  child: const Text('Receive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
