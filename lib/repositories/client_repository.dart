import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/utils/app_exception.dart';
import '../models/client.dart';
import '../models/user.dart';

class ClientRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Client>> getAll({String? search}) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (search != null && search.trim().isNotEmpty) {
      where.add(
          '(LOWER(nom) LIKE ? OR LOWER(prenom) LIKE ? OR telephone LIKE ? OR LOWER(numero_permis) LIKE ?)');
      final like = '%${search.trim().toLowerCase()}%';
      args.addAll([like, like, like, like]);
    }
    final rows = await db.query(
      'clients',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'nom, prenom',
    );
    return [for (final r in rows) Client.fromMap(r)];
  }

  Future<Client?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('clients', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Client.fromMap(rows.first);
  }

  Future<Client> getOrCreateForUser(User user) async {
    final db = await _db;
    final rows = await db.query(
      'clients',
      where: 'LOWER(email) = ?',
      whereArgs: [user.email.toLowerCase()],
    );
    if (rows.isNotEmpty) {
      return Client.fromMap(rows.first);
    }
    final client = Client(
      lastName: user.lastName,
      firstName: user.firstName,
      phone: '',
      email: user.email,
      licenseNumber: 'Permis-${user.id ?? 1}',
      createdAt: DateTime.now(),
    );
    final id = await insert(client);
    return client.copyWith(id: id);
  }

  Future<int> insert(Client client) async {
    final db = await _db;
    return db.insert('clients', client.toMap());
  }

  Future<void> update(Client client) async {
    final db = await _db;
    await db.update('clients', client.toMap(),
        where: 'id = ?', whereArgs: [client.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    final hasR = await hasRentals(id);
    if (hasR) {
      throw const AppException(
          'Suppression impossible : ce locataire a des locations.');
    }
    try {
      await db.delete('clients', where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintError()) {
        throw const AppException(
            'Suppression impossible : ce locataire a des locations.');
      }
      rethrow;
    }
  }

  Future<bool> hasRentals(int clientId) async {
    final db = await _db;
    final r = await db.rawQuery(
        'SELECT COUNT(*) FROM rentals WHERE client_id = ?', [clientId]);
    return (Sqflite.firstIntValue(r) ?? 0) > 0;
  }
}
