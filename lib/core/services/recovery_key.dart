import 'dart:math';

import 'password_hasher.dart';

/// Account recovery key, e.g. `K7M2-9QXA-4TPD-8WNB` (16 chars, ~80 bits).
/// The alphabet has no 0/O/1/I so the key is easy to read and copy by hand.
/// Only a salted hash is ever stored.
class RecoveryKey {
  RecoveryKey._();

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _length = 16;

  static String generate() {
    final r = Random.secure();
    final chars =
        List.generate(_length, (_) => _alphabet[r.nextInt(_alphabet.length)]);
    return [
      for (var i = 0; i < _length; i += 4) chars.sublist(i, i + 4).join(),
    ].join('-');
  }

  /// Uppercases and strips spaces/dashes so "k7m2 9qxa..." also works.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool looksValid(String input) => normalize(input).length == _length;

  static String hash(String key) => PasswordHasher.hash(normalize(key));

  static bool verify(String key, String storedHash) =>
      PasswordHasher.verify(normalize(key), storedHash);
}
