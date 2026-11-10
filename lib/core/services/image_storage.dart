import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_exception.dart';
import 'supabase_storage.dart';

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
  ///
  /// With [cloud], the photo is also uploaded to Supabase Storage in the
  /// background (vehicle photos); the local copy is always kept.
  static Future<String?> pickAndSave(ImageSource source,
      {bool cloud = false}) async {
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
      final saved = await File(picked.path).copy(join(_dir.path, name));
      if (cloud) unawaited(SupabaseStorage.uploadFile(name, saved));
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
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await fileFor(name).writeAsBytes(bytes, flush: true);
    // Demo cars are vehicle photos: mirror them in the cloud bucket too.
    unawaited(SupabaseStorage.uploadBytes(name, bytes));
    return name;
  }

  /// Deletes the local file; with [cloud], also the Supabase copy.
  static Future<void> delete(String fileName, {bool cloud = false}) async {
    final f = fileFor(fileName);
    if (await f.exists()) await f.delete();
    if (cloud) unawaited(SupabaseStorage.delete(fileName));
  }

  /// Downloads a vehicle photo from the cloud when it is missing locally
  /// (new device, cleared data). Returns true when the file is now there.
  static Future<bool> restoreFromCloud(String fileName) async {
    final f = fileFor(fileName);
    if (await f.exists()) return true;
    return SupabaseStorage.download(fileName, f);
  }
}
