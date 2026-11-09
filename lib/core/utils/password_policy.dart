enum PasswordStrength { weak, fair, good, strong }

/// Rules for NEW passwords (register, reset, change). Login keeps its own,
/// lighter validator so that older accounts can still sign in.
class PasswordPolicy {
  PasswordPolicy._();

  static const minLength = 8;

  static String? validate(String? v) {
    if (v == null || v.length < minLength) {
      return 'Minimum $minLength caractères';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    if (!hasLetter || !hasDigit) {
      return 'Au moins une lettre et un chiffre';
    }
    return null;
  }

  static PasswordStrength strength(String p) {
    if (p.length < minLength) return PasswordStrength.weak;
    var score = 1; // length >= 8
    if (p.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'\d').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    if (score <= 2) return PasswordStrength.fair;
    if (score == 3) return PasswordStrength.good;
    return PasswordStrength.strong;
  }
}
