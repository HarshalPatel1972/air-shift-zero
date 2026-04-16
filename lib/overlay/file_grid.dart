import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../theme/motion.dart';
import '../session/airshift_session.dart';
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
    return StreamBuilder<void>(
      stream: _session.incomingTransfer, // Reuses stream as a ping for UI updates
      builder: (context, _) {
        final files = _session.selectedFiles.toList();
        
        if (files.isEmpty) {
          return Center(
            child: Text(
              'No items selected.\nUse gestures to grab or take a screenshot!',
              textAlign: TextAlign.center,
              style: AirShiftTypography.label.copyWith(color: AirShiftColors.textSecondary),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
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

  const FileCard({
    super.key,
    required this.name,
    required this.path,
    required this.isScreenshot,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AirShiftMotion.grabConfirm,
      decoration: BoxDecoration(
        color: AirShiftColors.glassSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isScreenshot ? AirShiftColors.bluePrimary.withOpacity(0.5) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isScreenshot)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(path), fit: BoxFit.cover),
                ),
              ),
            )
          else
            const Icon(Icons.insert_drive_file, color: AirShiftColors.textPrimary, size: 48),
          
          if (!isScreenshot) const SizedBox(height: 12),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              name,
              style: AirShiftTypography.emphasis.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
