import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/services/password_hasher.dart';
import '../core/services/recovery_key.dart';
import '../core/services/totp_service.dart';
import '../core/utils/app_exception.dart';
import '../models/user.dart';
import '../models/user_activity.dart';
import '../models/user_report.dart';

/// [totpRequired]: password was correct but a 2FA code is still needed.
enum AuthStatus { success, invalid, locked, totpRequired }

class LoginResult {
  final AuthStatus status;
  final User? user;
  final int? attemptsLeft;
  final Duration? lockedFor;
  const LoginResult(this.status,
      {this.user, this.attemptsLeft, this.lockedFor});
}

class RecoveryResetResult {
  final AuthStatus status;

  /// A fresh recovery key (the one just used is single-use).
  final String? newRecoveryKey;
  final int? attemptsLeft;
  final Duration? lockedFor;

  /// True if the account had 2FA, which a recovery-key reset switches off.
  final bool totpDisabled;
  const RecoveryResetResult(this.status,
      {this.newRecoveryKey,
      this.attemptsLeft,
      this.lockedFor,
      this.totpDisabled = false});
}

class UserRepository {
  /// Failed attempts allowed before the account is temporarily locked.
  static const maxAttempts = 5;

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// 0 under [maxAttempts] failures, then 1 min doubling each failure, max 15 min.
  static Duration lockDurationFor(int failures) {
    if (failures < maxAttempts) return Duration.zero;
    final exp = math.min(failures - maxAttempts, 4);
    return Duration(seconds: math.min(60 * (1 << exp), 900));
  }

  Future<List<User>> getAll({String? search}) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (search != null && search.trim().isNotEmpty) {
      where.add('(LOWER(nom) LIKE ? OR LOWER(prenom) LIKE ? OR LOWER(email) LIKE ?)');
      final like = '%${search.trim().toLowerCase()}%';
      args.addAll([like, like, like]);
    }
    final rows = await db.query(
      'users',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'nom, prenom',
    );
    return [for (final r in rows) User.fromMap(r)];
  }

  Future<User?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<User?> getByEmail(String email) async {
    final db = await _db;
    final rows = await db.query('users',
        where: 'LOWER(email) = ?', whereArgs: [email.trim().toLowerCase()]);
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<bool> emailExists(String email, {int? excludeId}) async {
    final db = await _db;
    final where = excludeId == null
        ? 'LOWER(email) = ?'
        : 'LOWER(email) = ? AND id != ?';
    final args = excludeId == null
        ? [email.trim().toLowerCase()]
        : [email.trim().toLowerCase(), excludeId];
    final rows = await db.query('users', where: where, whereArgs: args, limit: 1);
    return rows.isNotEmpty;
  }

  /// Legacy check without lockout/logging. Prefer [signIn].
  Future<User?> authenticate(String email, String password) async {
    final user = await getByEmail(email);
    if (user == null) return null;
    return PasswordHasher.verify(password, user.passwordHash) ? user : null;
  }

  // ── Sign-in with brute-force protection ───────────────────────────────────

  Future<LoginResult> signIn(String email, String password) async {
    final db = await _db;
    final user = await getByEmail(email);
    if (user == null) return const LoginResult(AuthStatus.invalid);

    final now = DateTime.now();
    if (user.lockedUntil != null && user.lockedUntil!.isAfter(now)) {
      return LoginResult(AuthStatus.locked,
          lockedFor: user.lockedUntil!.difference(now));
    }

    if (PasswordHasher.verify(password, user.passwordHash)) {
      if (user.totpEnabled) {
        // Second factor still needed: no session yet, counters untouched.
        return LoginResult(AuthStatus.totpRequired, user: user);
      }
      await db.update('users', {'failed_attempts': 0, 'locked_until': null},
          where: 'id = ?', whereArgs: [user.id]);
      await logActivity(user.id!, ActivityAction.login);
      return LoginResult(AuthStatus.success, user: await getById(user.id!));
    }

    final lock = await _registerFailure(db, user, ActivityAction.loginFailed);
    if (lock.lockedFor != null) {
      return LoginResult(AuthStatus.locked, lockedFor: lock.lockedFor);
    }
    return LoginResult(AuthStatus.invalid,
        attemptsLeft: math.max(maxAttempts - lock.failures, 0));
  }

  /// Second step of a 2FA login: checks the 6-digit [code]. Wrong codes count
  /// toward the same lockout as wrong passwords.
  Future<LoginResult> completeTotpLogin(int userId, String code) async {
    final db = await _db;
    final user = await getById(userId);
    if (user == null || !user.totpEnabled) {
      return const LoginResult(AuthStatus.invalid);
    }
    final now = DateTime.now();
    if (user.lockedUntil != null && user.lockedUntil!.isAfter(now)) {
      return LoginResult(AuthStatus.locked,
          lockedFor: user.lockedUntil!.difference(now));
    }
    final step =
        Totp.verify(user.totpSecret!, code, lastStep: user.totpLastStep);
    if (step == null) {
      final lock = await _registerFailure(db, user, ActivityAction.totpFailed);
      if (lock.lockedFor != null) {
        return LoginResult(AuthStatus.locked, lockedFor: lock.lockedFor);
      }
      return LoginResult(AuthStatus.invalid,
          attemptsLeft: math.max(maxAttempts - lock.failures, 0));
    }
    await db.update(
      'users',
      {'failed_attempts': 0, 'locked_until': null, 'totp_last_step': step},
      where: 'id = ?',
      whereArgs: [userId],
    );
    await logActivity(userId, ActivityAction.login, detail: 'Avec 2FA');
    return LoginResult(AuthStatus.success, user: await getById(userId));
  }

  // ── Two-factor authentication (settings) ──────────────────────────────────

  /// True if [code] is currently valid for the user's secret (no side effects).
  Future<bool> checkTotpCode(int userId, String code) async {
    final user = await getById(userId);
    if (user == null || !user.totpEnabled) return false;
    return Totp.verify(user.totpSecret!, code) != null;
  }

  /// Turns 2FA on after the user proved their authenticator app works by
  /// entering a valid code for [secret].
  Future<void> enableTotp(int userId, String secret, String code) async {
    if (Totp.verify(secret, code) == null) {
      throw const AppException(
          'Code incorrect. Vérifiez aussi que l\'heure de votre appareil est exacte.');
    }
    final db = await _db;
    await db.update('users', {'totp_secret': secret, 'totp_last_step': 0},
        where: 'id = ?', whereArgs: [userId]);
    await logActivity(userId, ActivityAction.totpEnabled);
  }

  Future<void> disableTotp(int userId, {String? detail}) async {
    final db = await _db;
    await db.update('users', {'totp_secret': null, 'totp_last_step': 0},
        where: 'id = ?', whereArgs: [userId]);
    await logActivity(userId, ActivityAction.totpDisabled, detail: detail);
  }

  /// A colleague switches off 2FA for someone who lost their phone.
  Future<void> disableTotpByColleague({
    required int targetId,
    required int actorId,
  }) async {
    if (targetId == actorId) {
      throw const AppException(
          'Pour votre propre compte, utilisez « Sécurité du compte ».');
    }
    final actor = await getById(actorId);
    await disableTotp(targetId,
        detail: actor == null ? null : 'Par ${actor.fullName}');
  }

  Future<({int failures, Duration? lockedFor})> _registerFailure(
      Database db, User user, String action) async {
    final failures = user.failedAttempts + 1;
    final lock = lockDurationFor(failures);
    final until = lock == Duration.zero ? null : DateTime.now().add(lock);
    await db.update(
      'users',
      {'failed_attempts': failures, 'locked_until': until?.toIso8601String()},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    await logActivity(user.id!, action);
    if (until != null) {
      await logActivity(user.id!, ActivityAction.accountLocked,
          detail: 'Verrouillé ${lock.inSeconds} s');
    }
    return (failures: failures, lockedFor: until == null ? null : lock);
  }

  // ── Password recovery ─────────────────────────────────────────────────────

  /// Sets (or replaces) the recovery key. [plainKey] is hashed before storing.
  Future<void> setRecoveryKey(int userId, String plainKey) async {
    final db = await _db;
    await db.update('users', {'recovery_key_hash': RecoveryKey.hash(plainKey)},
        where: 'id = ?', whereArgs: [userId]);
    await logActivity(userId, ActivityAction.recoveryKeySet);
  }

  /// "Forgot password" without network: email + recovery key + new password.
  /// Wrong attempts share the login lockout, so the key cannot be brute-forced.
  /// The error is the same whether the email exists or not.
  Future<RecoveryResetResult> resetWithRecoveryKey({
    required String email,
    required String recoveryKey,
    required String newPassword,
  }) async {
    final db = await _db;
    final user = await getByEmail(email);
    if (user == null) return const RecoveryResetResult(AuthStatus.invalid);

    final now = DateTime.now();
    if (user.lockedUntil != null && user.lockedUntil!.isAfter(now)) {
      return RecoveryResetResult(AuthStatus.locked,
          lockedFor: user.lockedUntil!.difference(now));
    }

    final stored = user.recoveryKeyHash;
    if (stored == null || !RecoveryKey.verify(recoveryKey, stored)) {
      final lock =
          await _registerFailure(db, user, ActivityAction.recoveryFailed);
      if (lock.lockedFor != null) {
        return RecoveryResetResult(AuthStatus.locked, lockedFor: lock.lockedFor);
      }
      return RecoveryResetResult(AuthStatus.invalid,
          attemptsLeft: math.max(maxAttempts - lock.failures, 0));
    }

    final newKey = RecoveryKey.generate();
    final hadTotp = user.totpEnabled;
    await db.update(
      'users',
      {
        'password_hash': PasswordHasher.hash(newPassword),
        'recovery_key_hash': RecoveryKey.hash(newKey),
        // The recovery key is the master key: it also lifts 2FA (lost phone).
        'totp_secret': null,
        'totp_last_step': 0,
        'failed_attempts': 0,
        'locked_until': null,
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
    await logActivity(user.id!, ActivityAction.passwordResetRecovery);
    if (hadTotp) {
      await logActivity(user.id!, ActivityAction.totpDisabled,
          detail: 'Via la clé de récupération');
    }
    return RecoveryResetResult(AuthStatus.success,
        newRecoveryKey: newKey, totpDisabled: hadTotp);
  }

  /// A colleague sets a new password for someone else (forgotten password,
  /// no recovery key). Also clears any lockout. Logged on the target's account.
  Future<void> resetByColleague({
    required int targetId,
    required int actorId,
    required String newPassword,
  }) async {
    if (targetId == actorId) {
      throw const AppException(
          'Pour votre propre compte, utilisez « Mon profil » ou la clé de récupération.');
    }
    final db = await _db;
    final target = await getById(targetId);
    final actor = await getById(actorId);
    if (target == null) throw const AppException('Utilisateur introuvable.');
    await db.update(
      'users',
      {
        'password_hash': PasswordHasher.hash(newPassword),
        'failed_attempts': 0,
        'locked_until': null,
      },
      where: 'id = ?',
      whereArgs: [targetId],
    );
    await logActivity(targetId, ActivityAction.passwordResetColleague,
        detail: actor == null ? null : 'Par ${actor.fullName}');
  }

  /// Changes the password of [userId].
  Future<void> changePassword(int userId, String newPassword) async {
    final db = await _db;
    await db.update(
      'users',
      {'password_hash': PasswordHasher.hash(newPassword)},
      where: 'id = ?',
      whereArgs: [userId],
    );
    await logActivity(userId, ActivityAction.passwordChanged);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Inserts a new user; hashes [plainPassword].
  Future<int> insert(User user, String plainPassword) async {
    final db = await _db;
    if (await emailExists(user.email)) {
      throw const AppException('Cet email existe déjà.');
    }
    final hash = PasswordHasher.hash(plainPassword);
    final id =
        await db.insert('users', user.copyWith(passwordHash: hash).toMap());
    await logActivity(id, ActivityAction.accountCreated);
    return id;
  }

  Future<void> update(User user) async {
    final db = await _db;
    if (await emailExists(user.email, excludeId: user.id)) {
      throw const AppException('Cet email existe déjà.');
    }
    await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
    if (user.id != null) {
      await logActivity(user.id!, ActivityAction.profileUpdated);
    }
  }

  Future<void> updatePassword(String email, String plainPassword) async {
    final db = await _db;
    final hash = PasswordHasher.hash(plainPassword);
    await db.update('users', {'password_hash': hash},
        where: 'LOWER(email) = ?', whereArgs: [email.trim().toLowerCase()]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    final count = await this.count();
    if (count <= 1) {
      throw const AppException('Au moins un compte doit exister.');
    }
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) FROM users');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  // ── Business figures for the PDF report (read-only) ───────────────────────

  /// What this user did in the rentals / incidents modules. Only reads the
  /// tables owned by other modules; never writes to them.
  Future<BusinessStats> getBusinessStats(int userId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total,
        COALESCE(SUM(CASE WHEN statut = 'en_cours' THEN 1 ELSE 0 END), 0) AS active,
        COALESCE(SUM(CASE WHEN statut = 'terminee' THEN 1 ELSE 0 END), 0) AS completed,
        COALESCE(SUM(CASE WHEN statut = 'annulee'  THEN 1 ELSE 0 END), 0) AS cancelled,
        COALESCE(SUM(CASE WHEN statut != 'annulee' THEN prix_total ELSE 0 END), 0) AS revenue
      FROM rentals WHERE user_id = ?
    ''', [userId]);
    final r = rows.first;
    final incidents = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM incidents WHERE reported_by_user_id = ?',
            [userId])) ??
        0;
    return BusinessStats(
      rentals: (r['total'] as num?)?.toInt() ?? 0,
      active: (r['active'] as num?)?.toInt() ?? 0,
      completed: (r['completed'] as num?)?.toInt() ?? 0,
      cancelled: (r['cancelled'] as num?)?.toInt() ?? 0,
      revenue: (r['revenue'] as num?)?.toDouble() ?? 0,
      incidents: incidents,
    );
  }

  // ── Activity log ──────────────────────────────────────────────────────────

  /// Never throws: logging must not break the action being logged.
  Future<void> logActivity(int userId, String action, {String? detail}) async {
    try {
      final db = await _db;
      await db.insert(
        'user_activity',
        UserActivity(
          userId: userId,
          action: action,
          detail: detail,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    } catch (_) {}
  }

  Future<List<UserActivity>> getActivity(int userId, {int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(
      'user_activity',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return [for (final r in rows) UserActivity.fromMap(r)];
  }
}
