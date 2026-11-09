/// Action identifiers stored in `user_activity.action`.
class ActivityAction {
  ActivityAction._();
  static const accountCreated = 'account_created';
  static const login = 'login';
  static const loginFailed = 'login_failed';
  static const logout = 'logout';
  static const accountLocked = 'account_locked';
  static const passwordChanged = 'password_changed';
  static const passwordResetRecovery = 'password_reset_recovery';
  static const passwordResetColleague = 'password_reset_colleague';
  static const recoveryFailed = 'recovery_failed';
  static const recoveryKeySet = 'recovery_key_set';
  static const profileUpdated = 'profile_updated';
  static const totpEnabled = 'totp_enabled';
  static const totpDisabled = 'totp_disabled';
  static const totpFailed = 'totp_failed';
  static const reportExported = 'report_exported';
}

class UserActivity {
  final int? id;
  final int userId;
  final String action;
  final String? detail;
  final DateTime createdAt;

  const UserActivity({
    this.id,
    required this.userId,
    required this.action,
    this.detail,
    required this.createdAt,
  });

  String get label => switch (action) {
        ActivityAction.accountCreated => 'Compte créé',
        ActivityAction.login => 'Connexion',
        ActivityAction.loginFailed => 'Échec de connexion',
        ActivityAction.logout => 'Déconnexion',
        ActivityAction.accountLocked => 'Compte verrouillé temporairement',
        ActivityAction.passwordChanged => 'Mot de passe modifié',
        ActivityAction.passwordResetRecovery =>
          'Mot de passe réinitialisé (clé de récupération)',
        ActivityAction.passwordResetColleague =>
          'Mot de passe réinitialisé par un collègue',
        ActivityAction.recoveryFailed =>
          'Clé de récupération incorrecte',
        ActivityAction.recoveryKeySet => 'Clé de récupération générée',
        ActivityAction.profileUpdated => 'Profil modifié',
        ActivityAction.totpEnabled => 'Double authentification activée',
        ActivityAction.totpDisabled => 'Double authentification désactivée',
        ActivityAction.totpFailed => 'Code 2FA incorrect',
        ActivityAction.reportExported => 'Rapport PDF exporté',
        _ => action,
      };

  factory UserActivity.fromMap(Map<String, Object?> m) => UserActivity(
        id: m['id'] as int?,
        userId: m['user_id'] as int,
        action: m['action'] as String,
        detail: m['detail'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'action': action,
        'detail': detail,
        'created_at': createdAt.toIso8601String(),
      };
}
