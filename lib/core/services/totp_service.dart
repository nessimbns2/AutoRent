import 'dart:math';

import 'package:crypto/crypto.dart';

/// Time-based one-time passwords (RFC 6238, HMAC-SHA1, 6 digits, 30 s) —
/// the same codes produced by Google/Microsoft Authenticator, Authy, etc.
/// Everything is computed locally from a shared secret and the clock, so
/// no network is needed.
class Totp {
  Totp._();

  static const period = 30;
  static const digits = 6;
  static const _b32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// New random secret (160 bits), base32-encoded like authenticator apps expect.
  static String generateSecret({int bytes = 20}) {
    final r = Random.secure();
    return base32Encode(List<int>.generate(bytes, (_) => r.nextInt(256)));
  }

  static String base32Encode(List<int> data) {
    final out = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final b in data) {
      buffer = (buffer << 8) | b;
      bits += 8;
      while (bits >= 5) {
        out.write(_b32[(buffer >> (bits - 5)) & 31]);
        bits -= 5;
      }
      buffer &= (1 << bits) - 1;
    }
    if (bits > 0) out.write(_b32[(buffer << (5 - bits)) & 31]);
    return out.toString();
  }

  /// Returns null if [input] contains characters outside the base32 alphabet.
  static List<int>? base32Decode(String input) {
    final clean = input.toUpperCase().replaceAll(RegExp(r'[\s=-]'), '');
    final out = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final ch in clean.split('')) {
      final v = _b32.indexOf(ch);
      if (v < 0) return null;
      buffer = (buffer << 5) | v;
      bits += 5;
      if (bits >= 8) {
        out.add((buffer >> (bits - 8)) & 0xFF);
        bits -= 8;
        buffer &= (1 << bits) - 1;
      }
    }
    return out;
  }

  static int stepAt(DateTime time) =>
      (time.millisecondsSinceEpoch ~/ 1000) ~/ period;

  /// The code for one 30-second [step] (RFC 4226 dynamic truncation).
  static String codeForStep(List<int> key, int step, {int digits = Totp.digits}) {
    final msg = List<int>.filled(8, 0);
    var s = step;
    for (var i = 7; i >= 0; i--) {
      msg[i] = s & 0xFF;
      s >>= 8;
    }
    final hash = Hmac(sha1, key).convert(msg).bytes;
    final off = hash[19] & 0x0F;
    final bin = ((hash[off] & 0x7F) << 24) |
        (hash[off + 1] << 16) |
        (hash[off + 2] << 8) |
        hash[off + 3];
    var mod = 1;
    for (var i = 0; i < digits; i++) {
      mod *= 10;
    }
    return (bin % mod).toString().padLeft(digits, '0');
  }

  /// Checks [input] against the current step ± [window] steps (clock drift).
  /// Returns the matching step, or null. Steps <= [lastStep] are rejected so
  /// a code cannot be replayed.
  static int? verify(
    String secret,
    String input, {
    DateTime? now,
    int window = 1,
    int lastStep = 0,
  }) {
    final code = input.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return null;
    final key = base32Decode(secret);
    if (key == null || key.isEmpty) return null;
    final current = stepAt(now ?? DateTime.now());
    for (var d = -window; d <= window; d++) {
      final step = current + d;
      if (step < 0 || step <= lastStep) continue;
      if (codeForStep(key, step) == code) return step;
    }
    return null;
  }

  /// URI encoded in the QR code (Key URI format used by authenticator apps).
  static String otpauthUri({
    required String secret,
    required String account,
    String issuer = 'AutoRent',
  }) {
    final i = Uri.encodeComponent(issuer);
    return 'otpauth://totp/$i:${Uri.encodeComponent(account)}'
        '?secret=$secret&issuer=$i&algorithm=SHA1&digits=$digits&period=$period';
  }

  /// "ABCD EFGH IJKL ..." for manual entry.
  static String formatSecret(String secret) => [
        for (var i = 0; i < secret.length; i += 4)
          secret.substring(i, min(i + 4, secret.length)),
      ].join(' ');
}
