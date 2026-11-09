class Validators {
  Validators._();

  static String? required(String? v, [String field = 'Ce champ']) =>
      (v == null || v.trim().isEmpty) ? '$field est obligatoire' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email obligatoire';
    final ok = RegExp(r'^[^\@\s]+@[^\@\s]+\.[^\@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Email invalide';
  }

  static String? password(String? v) =>
      (v == null || v.length < 6)
          ? 'Mot de passe invalide (6 caractères minimum)'
          : null;

  static String? Function(String?) confirm(
          String Function() getOriginal) =>
      (v) => v == getOriginal() ? null : 'Les mots de passe ne correspondent pas';

  static String? phone(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'[\s+\-()]'), '');
    return RegExp(r'^\d{8,15}$').hasMatch(digits)
        ? null
        : 'Numéro de téléphone invalide';
  }

  /// Tunisian plate: series (1–3 digits) + "TUN" + number (1–4 digits),
  /// e.g. "123 TUN 4567".
  static final tunisianPlate = RegExp(r'^\d{1,3} TUN \d{1,4}$');

  static String? plate(String? v) {
    final p = (v ?? '').trim().toUpperCase();
    if (p.isEmpty) return "L'immatriculation est obligatoire";
    return tunisianPlate.hasMatch(p)
        ? null
        : 'Format attendu : 123 TUN 4567';
  }

  /// Optional whole number between [min] and [max].
  static String? optionalIntRange(String? v, int min, int max, String field) {
    final t = (v ?? '').trim().replaceAll(' ', '');
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n < min || n > max) {
      return '$field doit être entre $min et $max';
    }
    return null;
  }

  static String? positiveNumber(String? v, [String field = 'Valeur']) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    return (n == null || n <= 0) ? '$field doit être supérieure à 0' : null;
  }

  static String? minLength(String? v, int min, [String field = 'Ce champ']) {
    if (v == null || v.trim().isEmpty) return '$field est obligatoire';
    if (v.trim().length < min) return '$field doit contenir au moins $min caractères';
    return null;
  }
}
