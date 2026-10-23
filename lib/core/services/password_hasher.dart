import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PasswordHasher {
  PasswordHasher._();

  static String hash(String password) {
    final salt = _randomSalt();
    return '$salt:${_digest(salt, password)}';
  }

  static bool verify(String password, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return _digest(parts[0], password) == parts[1];
  }

  static String _digest(String salt, String password) =>
      sha256.convert(utf8.encode('$salt$password')).toString();

  static String _randomSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }
}
