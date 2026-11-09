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
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

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
        title: Text('Photo ${_currentIndex + 1} / $count'),
      ),
      body: Stack(children: [
        PageView.builder(
          controller: _pageController,
          itemCount: count,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, i) => InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Image.file(
                ImageStorage.fileFor(widget.fileNames[i]),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_rounded,
                    size: 64,
                    color: Colors.white38),
              ),
            ),
          ),
        ),
        if (count > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _currentIndex ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _currentIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}
