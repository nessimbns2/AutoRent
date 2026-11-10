import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Cloud storage of the vehicle photos in a public Supabase Storage bucket.
///
/// The phone / PC keeps a local copy (fast, works offline); every photo is
/// also uploaded so it can be downloaded again when the local file is
/// missing. The key below is the project's *publishable* key: it is meant
/// to be public, and the bucket policies only allow reading, uploading and
/// deleting images (5 MB max) in the `vehicle-photos` bucket.
class SupabaseStorage {
  SupabaseStorage._();

  static const projectUrl = 'https://yrgxysnybsllsipayoad.supabase.co';
  static const publishableKey = 'sb_publishable_oIUUMRP7MVdNrBWNFOYZPw_xlgWj7Ph';
  static const bucket = 'vehicle-photos';

  /// Off by default (tests, offline demos); switched on by main().
  static bool enabled = false;

  static const _timeout = Duration(seconds: 20);

  static Map<String, String> get _headers => {'apikey': publishableKey};

  /// Public URL of a stored photo.
  static String publicUrl(String fileName) =>
      '$projectUrl/storage/v1/object/public/$bucket/${Uri.encodeComponent(fileName)}';

  static String _mime(String fileName) =>
      switch (p.extension(fileName).toLowerCase()) {
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  /// Uploads [bytes] as [fileName] (replaces an existing file). Never
  /// throws: returns false when offline or refused, the local copy stays.
  static Future<bool> uploadBytes(String fileName, Uint8List bytes) async {
    if (!enabled) return false;
    try {
      final res = await http
          .post(
            Uri.parse(
                '$projectUrl/storage/v1/object/$bucket/${Uri.encodeComponent(fileName)}'),
            headers: {
              ..._headers,
              'Content-Type': _mime(fileName),
              'x-upsert': 'true',
            },
            body: bytes,
          )
          .timeout(_timeout);
      if (res.statusCode >= 300) {
        debugPrint('Supabase upload $fileName: ${res.statusCode} ${res.body}');
      }
      return res.statusCode < 300;
    } catch (e) {
      debugPrint('Supabase upload $fileName failed: $e');
      return false;
    }
  }

  static Future<bool> uploadFile(String fileName, File file) async {
    if (!enabled) return false;
    try {
      return await uploadBytes(fileName, await file.readAsBytes());
    } catch (_) {
      return false;
    }
  }

  /// Downloads [fileName] into [target] when it is missing locally.
  static Future<bool> download(String fileName, File target) async {
    if (!enabled) return false;
    try {
      final res = await http
          .get(Uri.parse(publicUrl(fileName)), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode != 200) return false;
      await target.writeAsBytes(res.bodyBytes, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> delete(String fileName) async {
    if (!enabled) return;
    try {
      await http
          .delete(
            Uri.parse(
                '$projectUrl/storage/v1/object/$bucket/${Uri.encodeComponent(fileName)}'),
            headers: _headers,
          )
          .timeout(_timeout);
    } catch (_) {
      // Offline: the local deletion still goes through.
    }
  }
}
