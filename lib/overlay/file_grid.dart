import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../theme/motion.dart';
import '../session/airshift_session.dart';
import '../session/session_state.dart';
import 'package:path/path.dart' as p;

class FileGrid extends StatefulWidget {
  const FileGrid({super.key});

  @override
  State<FileGrid> createState() => _FileGridState();
}

class _FileGridState extends State<FileGrid> {
  final _session = AirShiftSession.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SessionState>(
      stream: _session.stateStream,
      initialData: _session.currentState,
      builder: (context, snapshot) {
        final sessionState = snapshot.data ?? SessionState.active;
        final files = _session.selectedFiles.toList();
        
        if (files.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gesture, 
                  color: AirShiftColors.bluePrimary, 
                  size: 48,
                  shadows: [Shadow(color: AirShiftColors.bluePrimary, blurRadius: 12)],
                ),
                const SizedBox(height: 24),
                Text(
                  'No items selected.\nHover to grab or take a "Victory" screenshot.',
                  textAlign: TextAlign.center,
                  style: AirShiftTypography.label.copyWith(color: AirShiftColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 100),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 0.9,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final filePath = files[index];
              final fileName = p.basename(filePath);
              final isScreenshot = fileName.contains('AirShift_Snap');

              return FileCard(
                name: fileName,
                path: filePath,
                isScreenshot: isScreenshot,
                isHolding: sessionState == SessionState.holding,
              );
            },
          ),
        );
      },
    );
  }
}

class FileCard extends StatelessWidget {
  final String name;
  final String path;
  final bool isScreenshot;
  final bool isHolding;

  const FileCard({
    super.key,
    required this.name,
    required this.path,
    required this.isScreenshot,
    required this.isHolding,
  });

  @override
  Widget build(BuildContext context) {
    // Cinematic Color Transition (Blue -> Green)
    final activeColor = isHolding ? AirShiftColors.greenConfirm : AirShiftColors.bluePrimary;

    return AnimatedContainer(
      duration: AirShiftMotion.grabConfirm,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AirShiftColors.glassSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activeColor.withOpacity(0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: activeColor.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withOpacity(0.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isScreenshot 
                    ? Image.file(File(path), fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.description, color: AirShiftColors.textSecondary, size: 40)),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AirShiftTypography.emphasis.copyWith(fontSize: 13, color: AirShiftColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isScreenshot ? 'Screenshot' : 'File Asset',
                  style: AirShiftTypography.label.copyWith(fontSize: 10, color: AirShiftColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
