import 'package:flutter/material.dart';

import '../../core/services/image_storage.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<String> fileNames;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.fileNames,
    this.initialIndex = 0,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.fileNames.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / $count'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: count,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, i) {
          final fileName = widget.fileNames[i];
          final file = ImageStorage.fileFor(fileName);
          return InteractiveViewer(
            child: Center(
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image, size: 64, color: Colors.white54),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
