import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/services/password_hasher.dart';
import '../core/utils/app_exception.dart';
import '../models/user.dart';

class UserRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

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

  Future<User?> authenticate(String email, String password) async {
    final user = await getByEmail(email);
    if (user == null) return null;
    return PasswordHasher.verify(password, user.passwordHash) ? user : null;
  }

  /// Inserts a new user; hashes [plainPassword].
  Future<int> insert(User user, String plainPassword) async {
    final db = await _db;
    if (await emailExists(user.email)) {
      throw const AppException('Cet email existe déjà.');
    }
    final hash = PasswordHasher.hash(plainPassword);
    return db.insert('users', user.copyWith(passwordHash: hash).toMap());
  }

  Future<void> update(User user) async {
    final db = await _db;
    if (await emailExists(user.email, excludeId: user.id)) {
      throw const AppException('Cet email existe déjà.');
    }
    await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
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

  /// (rentals created, revenue of those rentals, incidents reported)
  Future<(int, double, int)> activity(int userId) async {
    final db = await _db;
    final r = await db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM rentals WHERE user_id = ?) AS rentals,
        (SELECT COALESCE(SUM(prix_total), 0) FROM rentals
           WHERE user_id = ? AND statut != 'annulee') AS revenue,
        (SELECT COUNT(*) FROM incidents WHERE reported_by_user_id = ?) AS incidents
    ''', [userId, userId, userId]);
    final row = r.first;
    return (
      row['rentals'] as int,
      (row['revenue'] as num).toDouble(),
      row['incidents'] as int,
    );
  }
}
