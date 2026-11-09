import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LoadingView
// ─────────────────────────────────────────────────────────────────────────────
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

// ─────────────────────────────────────────────────────────────────────────────
// ErrorView
// ─────────────────────────────────────────────────────────────────────────────
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// EmptyState
// ─────────────────────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState(
      {super.key, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ]
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// StatusChip
// ─────────────────────────────────────────────────────────────────────────────
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SearchField
// ─────────────────────────────────────────────────────────────────────────────
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: onChanged,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SectionCard
// ─────────────────────────────────────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SectionCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Divider(height: 16),
              ...children,
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// LabeledRow — used in detail screens
// ─────────────────────────────────────────────────────────────────────────────
class LabeledRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  const LabeledRow(
      {super.key, required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Row(children: [
                Expanded(
                    child: Text(value,
                        style: Theme.of(context).textTheme.bodyMedium)),
                ?trailing,
              ]),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// CarImage — Image.file with fallback to asset placeholder
// ─────────────────────────────────────────────────────────────────────────────
class CarImage extends StatelessWidget {
  final String? fileName;
  final BoxFit fit;
  final double? width;
  final double? height;
  const CarImage(
      {super.key,
      this.fileName,
      this.fit = BoxFit.cover,
      this.width,
      this.height});

  @override
  Widget build(BuildContext context) {
    if (fileName == null) {
      return Image.asset('assets/images/car_placeholder.png',
          fit: fit, width: width, height: height);
    }
    final file = ImageStorage.fileFor(fileName!);
    return Image.file(
      file,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => Image.asset(
          'assets/images/car_placeholder.png',
          fit: fit,
          width: width,
          height: height),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PhotoStrip — horizontal scrollable strip of photo thumbnails
// ─────────────────────────────────────────────────────────────────────────────
class PhotoStrip extends StatelessWidget {
  final List<String> fileNames;
  final void Function(int index) onTap;
  const PhotoStrip({super.key, required this.fileNames, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (fileNames.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: fileNames.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => onTap(i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CarImage(fileName: fileNames[i], width: 80, height: 80),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PhotoPickerField
// ─────────────────────────────────────────────────────────────────────────────
class PhotoPickerField extends StatefulWidget {
  final List<String> fileNames;
  final int maxPhotos;
  final ValueChanged<List<String>> onChanged;
  const PhotoPickerField({
    super.key,
    required this.fileNames,
    required this.onChanged,
    this.maxPhotos = 6,
  });

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  late List<String> _files;

  @override
  void initState() {
    super.initState();
    _files = List<String>.from(widget.fileNames);
  }

  Future<void> _addPhoto() async {
    final source = await _pickSource();
    if (source == null || !mounted) return;
    final name = await ImageStorage.pickAndSave(source);
    if (name == null || !mounted) return;
    setState(() => _files.add(name));
    widget.onChanged(_files);
  }

  void _removePhoto(int i) {
    setState(() => _files.removeAt(i));
    widget.onChanged(_files);
  }

  Future<ImageSource?> _pickSource() => showModalBottomSheet<ImageSource>(
        context: context,
        builder: (_) => SafeArea(
          child: Wrap(children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Appareil photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._files.asMap().entries.map((e) => Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CarImage(
                          fileName: e.value, width: 80, height: 80),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _removePhoto(e.key),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )),
          if (_files.length < widget.maxPhotos)
            GestureDetector(
              onTap: _addPhoto,
              child: Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).colorScheme.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 4),
                    Text('Ajouter',
                        style: TextStyle(
                            fontSize: 10,
                            color:
                                Theme.of(context).colorScheme.primary)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ResponsiveCenter — Constrains and centers content on wide screens
// ─────────────────────────────────────────────────────────────────────────────
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 850,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}
