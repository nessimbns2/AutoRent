import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class ImageStorage {
  ImageStorage._();

  static late Directory _dir;

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _dir = Directory(join(docs.path, 'photos'));
    if (!await _dir.exists()) await _dir.create(recursive: true);
  }

  /// Returns a [File] synchronously — safe to use in Image.file without FutureBuilder.
  static File fileFor(String fileName) => File(join(_dir.path, fileName));

  /// Picks an image from [source], copies it into the photos directory,
  /// and returns only the file name (never an absolute path).
  static Future<String?> pickAndSave(ImageSource source) async {
    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (picked == null) return null;
    final ext = extension(picked.path).isEmpty ? '.jpg' : extension(picked.path);
    final name = '${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(picked.path).copy(join(_dir.path, name));
    return name;
  }

  static Future<void> delete(String fileName) async {
    final f = fileFor(fileName);
    if (await f.exists()) await f.delete();
  }
}
