import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/colors.dart';

class AirShiftSmartPreview extends StatefulWidget {
  final File file;
  final String mimeType;

  const AirShiftSmartPreview({
    super.key,
    required this.file,
    required this.mimeType,
  });

  @override
  State<AirShiftSmartPreview> createState() => _AirShiftSmartPreviewState();
}

class _AirShiftSmartPreviewState extends State<AirShiftSmartPreview> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.mimeType.startsWith('video/')) {
      _videoController = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          setState(() {});
          _videoController?.setVolume(0);
          _videoController?.play();
          _videoController?.setLooping(true);
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mimeType.startsWith('image/')) {
      return Image.file(
        widget.file,
        fit: BoxFit.cover,
      );
    } else if (widget.mimeType.startsWith('video/')) {
      return _videoController?.value.isInitialized ?? false
          ? AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            )
          : const Center(child: CircularProgressIndicator());
    } else if (widget.mimeType.startsWith('audio/')) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.audiotrack, size: 64, color: AirShiftColors.bluePrimary),
            const SizedBox(height: 16),
            Text(
              'Audio File',
              style: TextStyle(color: AirShiftColors.textPrimary),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, size: 64, color: AirShiftColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              widget.file.path.split('/').last,
              textAlign: TextAlign.center,
              style: TextStyle(color: AirShiftColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Open'),
            ),
          ],
        ),
      );
    }
  }
}
