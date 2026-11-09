import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_exception.dart';

class ImageStorage {
  ImageStorage._();

  static late Directory _dir;

  /// Must run before the database is opened (the demo data copies the
  /// bundled vehicle photos into this folder). [directory] is for tests.
  static Future<void> init({Directory? directory}) async {
    if (directory != null) {
      _dir = directory;
    } else {
      final docs = await getApplicationDocumentsDirectory();
      _dir = Directory(join(docs.path, 'photos'));
    }
    if (!await _dir.exists()) await _dir.create(recursive: true);
  }

  /// Returns a [File] synchronously — safe to use in Image.file without FutureBuilder.
  static File fileFor(String fileName) => File(join(_dir.path, fileName));

  /// Picks an image from [source], copies it into the photos directory,
  /// and returns only the file name (never an absolute path), or null if the
  /// user cancelled. Throws an [AppException] with a French message when the
  /// camera / gallery is unavailable or the file cannot be copied.
  static Future<String?> pickAndSave(ImageSource source) async {
    if (!ImagePicker().supportsImageSource(source)) {
      throw AppException(source == ImageSource.camera
          ? "L'appareil photo n'est pas disponible sur cet appareil."
          : "La galerie n'est pas disponible sur cet appareil.");
    }
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (picked == null) return null;
      final ext =
          extension(picked.path).isEmpty ? '.jpg' : extension(picked.path);
      final name = '${DateTime.now().microsecondsSinceEpoch}$ext';
      await File(picked.path).copy(join(_dir.path, name));
      return name;
    } on PlatformException catch (e) {
      throw AppException(e.code == 'camera_access_denied' ||
              e.code == 'photo_access_denied'
          ? "Accès refusé : autorisez l'appareil photo / les photos dans les réglages."
          : "Impossible d'ouvrir l'image (${e.message ?? e.code}).");
    } on FileSystemException {
      throw const AppException("Impossible d'enregistrer la photo.");
    }
  }

  /// Copies a bundled asset (e.g. assets/vehicles/audi_q3.jpg) into the
  /// photos directory and returns the stored file name.
  static Future<String> installAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final name = 'demo_${basename(assetPath)}';
    await fileFor(name).writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return name;
  }

  static Future<void> delete(String fileName) async {
    final f = fileFor(fileName);
    if (await f.exists()) await f.delete();
  }
}
