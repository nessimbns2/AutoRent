# Code templates — local storage

Starting points. Adapt names to the generated code; keep the behaviour.

## DatabaseHelper

```dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'autorent.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    for (final statement in _schemaStatements) {
      await db.execute(statement);
    }
    await _seed(db);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // if (oldV < 2) { await db.execute('ALTER TABLE ...'); }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // _schemaStatements: List<String> copied from references/schema.sql
  // _seed(db): inserts default users, clients, vehicles, ... (see SKILL.md)
}
```

## Model example (Vehicle)

```dart
class Vehicle {
  final int? id;
  final String brand;          // column: marque
  final String model;          // column: modele
  final String plate;          // column: immatriculation
  final double pricePerDay;    // column: prix_par_jour
  final bool available;        // column: disponible (0/1)
  final DateTime createdAt;
  final List<String> photos;   // file names, loaded separately from vehicle_photos

  const Vehicle({
    this.id,
    required this.brand,
    required this.model,
    required this.plate,
    required this.pricePerDay,
    this.available = true,
    required this.createdAt,
    this.photos = const [],
  });

  factory Vehicle.fromMap(Map<String, Object?> m, {List<String> photos = const []}) => Vehicle(
        id: m['id'] as int?,
        brand: m['marque'] as String,
        model: m['modele'] as String,
        plate: m['immatriculation'] as String,
        pricePerDay: (m['prix_par_jour'] as num).toDouble(),
        available: (m['disponible'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        photos: photos,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'marque': brand,
        'modele': model,
        'immatriculation': plate,
        'prix_par_jour': pricePerDay,
        'disponible': available ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  Vehicle copyWith({/* … */}) => /* … */;
}
```

## Enum example

```dart
enum RentalStatus {
  reservee('reservee', 'Réservée'),
  enCours('en_cours', 'En cours'),
  terminee('terminee', 'Terminée'),
  annulee('annulee', 'Annulée');

  const RentalStatus(this.value, this.label);
  final String value;
  final String label;

  static RentalStatus fromValue(String v) =>
      RentalStatus.values.firstWhere((s) => s.value == v);
}
```

## Repository example (Vehicle)

```dart
class VehicleRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Vehicle>> getAll({bool? availableOnly, String? search}) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (availableOnly == true) where.add('disponible = 1');
    if (availableOnly == false) where.add('disponible = 0');
    if (search != null && search.trim().isNotEmpty) {
      where.add('(marque LIKE ? OR modele LIKE ? OR immatriculation LIKE ?)');
      final like = '%${search.trim()}%';
      args.addAll([like, like, like]);
    }
    final rows = await db.query(
      'vehicles',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'marque, modele',
    );
    // cover photo for each card: one extra query per vehicle is fine at this scale,
    // or join vehicle_photos WHERE position = 0.
    return [for (final r in rows) Vehicle.fromMap(r, photos: await getPhotos(r['id'] as int))];
  }

  Future<List<String>> getPhotos(int vehicleId) async {
    final db = await _db;
    final rows = await db.query('vehicle_photos',
        where: 'vehicle_id = ?', whereArgs: [vehicleId], orderBy: 'position');
    return [for (final r in rows) r['file_name'] as String];
  }

  Future<int> insert(Vehicle v) async {
    final db = await _db;
    return db.transaction((txn) async {
      final id = await txn.insert('vehicles', v.toMap());
      await _writePhotos(txn, id, v.photos);
      return id;
    });
  }

  Future<void> delete(int id) async {
    final db = await _db;
    final photos = await getPhotos(id);
    try {
      await db.delete('vehicles', where: 'id = ?', whereArgs: [id]); // may throw FK error
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintError()) {
        throw const AppException('Suppression impossible : ce véhicule a des locations ou des incidents.');
      }
      rethrow;
    }
    for (final f in photos) {
      await ImageStorage.delete(f); // only after the DB delete succeeded
    }
  }

  Future<void> _writePhotos(DatabaseExecutor ex, int vehicleId, List<String> files) async {
    await ex.delete('vehicle_photos', where: 'vehicle_id = ?', whereArgs: [vehicleId]);
    for (var i = 0; i < files.length; i++) {
      await ex.insert('vehicle_photos', {'vehicle_id': vehicleId, 'file_name': files[i], 'position': i});
    }
  }
}
```

`AppException(message)` is a tiny class in `core/utils/` that repositories throw and screens show in a SnackBar.

## PasswordHasher

```dart
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class PasswordHasher {
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
```

## SessionManager

```dart
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();
  static const _key = 'session_user_id';

  User? _user;
  User? get currentUser => _user;
  bool get isLoggedIn => _user != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_key);
    if (id == null) return;
    _user = await UserRepository().getById(id);
    if (_user == null) await prefs.remove(_key);
  }

  Future<void> login(User user) async {
    _user = user;
    (await SharedPreferences.getInstance()).setInt(_key, user.id!);
  }

  Future<void> refresh() async { // call after the profile is edited
    if (_user?.id != null) _user = await UserRepository().getById(_user!.id!);
  }

  Future<void> logout() async {
    _user = null;
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}
```

## ImageStorage

```dart
class ImageStorage {
  static late Directory _dir;

  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _dir = Directory(join(docs.path, 'photos'));
    if (!await _dir.exists()) await _dir.create(recursive: true);
  }

  static File fileFor(String fileName) => File(join(_dir.path, fileName));

  static Future<String?> pickAndSave(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (picked == null) return null;
    final name = '${DateTime.now().microsecondsSinceEpoch}${extension(picked.path).isEmpty ? '.jpg' : extension(picked.path)}';
    await File(picked.path).copy(join(_dir.path, name));
    return name;
  }

  static Future<void> delete(String fileName) async {
    final f = fileFor(fileName);
    if (await f.exists()) await f.delete();
  }
}
```
