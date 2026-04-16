import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import 'paper_animation.dart';
import 'smart_preview.dart';

class AirShiftReceiveOverlay extends StatefulWidget {
  final String senderName;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final File? receivedFile; // Null if still transferring
  final bool isFailed;

  const AirShiftReceiveOverlay({
    super.key,
    required this.senderName,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    this.receivedFile,
    this.isFailed = false,
  });

  @override
  State<AirShiftReceiveOverlay> createState() => _AirShiftReceiveOverlayState();
}

class _AirShiftReceiveOverlayState extends State<AirShiftReceiveOverlay> {
  late PaperState _paperState;

  @override
  void initState() {
    super.initState();
    _paperState = widget.receivedFile != null ? PaperState.unwrap : PaperState.pulse;
  }

  @override
  void didUpdateWidget(AirShiftReceiveOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.receivedFile != null && oldWidget.receivedFile == null) {
      setState(() {
        _paperState = PaperState.unwrap;
      });
      
      // After unwrap animation finishes
      Future.delayed(AirShiftMotion.paperUnwrap, () {
        if (mounted) {
          setState(() {
            _paperState = PaperState.open;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Background Dim
          Container(color: Colors.black.withOpacity(0.4)),
          
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Incoming from ${widget.senderName}',
                  style: TextStyle(
                    color: AirShiftColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.fileName,
                  style: const TextStyle(
                    color: AirShiftColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 40),
                
                AirShiftPaperAnimation(
                  state: _paperState,
                  child: widget.receivedFile != null 
                    ? AirShiftSmartPreview(
                        file: widget.receivedFile!, 
                        mimeType: widget.mimeType
                      )
                    : null,
                ),
                
                if (widget.isFailed) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Transfer Failed',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          
          // Close button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () {
                // Should hide the overlay via session manager
              },
            ),
          ),
        ],
      ),
    );
  }
}
