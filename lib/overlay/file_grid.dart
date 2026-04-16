import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../theme/motion.dart';

class FileModel {
  final String name;
  final String size;
  final IconData icon;

  FileModel({required this.name, required this.size, required this.icon});
}

class FileGrid extends StatefulWidget {
  const FileGrid({super.key});

  @override
  State<FileGrid> createState() => _FileGridState();
}

class _FileGridState extends State<FileGrid> {
  final List<FileModel> _files = [
    FileModel(name: 'IMG_2024.jpg', size: '2.4 MB', icon: Icons.image),
    FileModel(name: 'Project_Design.pdf', size: '1.1 MB', icon: Icons.picture_as_pdf),
    FileModel(name: 'Meeting_Recording.mp4', size: '45 MB', icon: Icons.video_library),
    FileModel(name: 'Draft_v1.docx', size: '342 KB', icon: Icons.description),
  ];

  final Set<int> _selectedIndices = {};
  bool _isGrabbed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          final isSelected = _selectedIndices.contains(index);
          
          return FileCard(
            file: file,
            isSelected: isSelected,
            isGrabbed: _isGrabbed && isSelected,
          );
        },
      ),
    );
  }
}

class FileCard extends StatelessWidget {
  final FileModel file;
  final bool isSelected;
  final bool isGrabbed;

  const FileCard({
    super.key,
    required this.file,
    required this.isSelected,
    required this.isGrabbed,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isGrabbed 
        ? AirShiftColors.greenConfirm 
        : (isSelected ? AirShiftColors.bluePrimary : Colors.transparent);

    return AnimatedContainer(
      duration: AirShiftMotion.grabConfirm,
      decoration: BoxDecoration(
        color: AirShiftColors.glassSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(file.icon, color: AirShiftColors.textPrimary, size: 48),
          const SizedBox(height: 12),
          Text(
            file.name,
            style: AirShiftTypography.emphasis,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            file.size,
            style: AirShiftTypography.label,
          ),
        ],
      ),
    );
  }
}
