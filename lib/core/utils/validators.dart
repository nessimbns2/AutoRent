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

  static String? plate(String? v) =>
      (v == null || v.trim().length < 4) ? 'Immatriculation invalide' : null;

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
