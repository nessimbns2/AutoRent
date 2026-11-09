import 'package:sqflite/sqflite.dart';

import '../services/image_storage.dart';
import '../services/password_hasher.dart';

/// Demonstration data: accounts, clients and a fleet of 6 photographed cars
/// with rentals, maintenance and incidents. Dates are relative to the day the
/// data is installed so the dashboard and notifications always have content
/// (a late rental, a pick-up and a return today, an overdue service…).
class DemoData {
  DemoData._();

  static const _clients = <(String, String, String, String?, String)>[
    // (nom, prénom, téléphone, email, n° permis)
    ('Hamdi', 'Rania', '22334455', 'rania@example.com', 'P123456'),
    ('Trabelsi', 'Mohamed', '55667788', null, 'P789012'),
    ('Bouzid', 'Leila', '98765432', 'leila.bouzid@example.com', 'P345678'),
    ('Gharbi', 'Youssef', '20123456', 'youssef.gharbi@example.com', 'P456789'),
    ('Khelifi', 'Amira', '52987654', 'amira.khelifi@example.com', 'P567890'),
    ('Jaziri', 'Karim', '98112233', 'karim.jaziri@example.com', 'P678901'),
    ('Mansouri', 'Ines', '23456789', 'ines.mansouri@example.com', 'P890123'),
    ('Saidi', 'Omar', '55443322', null, 'P901234'),
  ];

  /// (marque, modèle, immatriculation, prix/jour, photo, ajouté il y a n jours)
  static const _fleet = <(String, String, String, double, String, int)>[
    ('Suzuki', 'Swift', '128 TUN 4521', 85, 'suzuki_swift', 200),
    ('Škoda', 'Fabia', '215 TUN 7834', 95, 'skoda_fabia', 180),
    ('Dacia', 'Logan', '187 TUN 3390', 70, 'dacia_logan', 240),
    ('Peugeot', '208', '231 TUN 1056', 90, 'peugeot_208', 160),
    ('Renault', 'Clio', '176 TUN 8812', 80, 'renault_clio', 220),
    ('Audi', 'Q3', '240 TUN 2468', 220, 'audi_q3', 90),
  ];

  static String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  // ── Accounts & clients ─────────────────────────────────────────────────────

  static Future<void> seedAccounts(DatabaseExecutor db) async {
    final ts = DateTime.now().toIso8601String();
    for (final (nom, prenom, email, pass) in const [
      ('Administrateur', 'AutoRent', 'admin@autorent.tn', 'Admin123!'),
      ('Ben Ali', 'Sami', 'agent@autorent.tn', 'Agent123!'),
    ]) {
      final exists = await db.query('users',
          where: 'LOWER(email) = ?', whereArgs: [email], limit: 1);
      if (exists.isNotEmpty) continue;
      await db.insert('users', {
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'password_hash': PasswordHasher.hash(pass),
        'created_at': ts,
      });
    }
    for (final (nom, prenom, tel, email, permis) in _clients) {
      final exists = await db.query('clients',
          where: 'numero_permis = ?', whereArgs: [permis], limit: 1);
      if (exists.isNotEmpty) continue;
      await db.insert('clients', {
        'nom': nom,
        'prenom': prenom,
        'telephone': tel,
        'email': ?email,
        'numero_permis': permis,
        'created_at': ts,
      });
    }
  }

  // ── Fleet reset (migration v2) ─────────────────────────────────────────────

  /// Removes every vehicle with its rentals, maintenance and incidents.
  /// Users and clients are kept.
  static Future<void> resetFleet(DatabaseExecutor db) async {
    const tables = [
      'incident_history',
      'incident_photos',
      'incidents',
      'rentals',
      'maintenances',
      'vehicle_photos',
      'vehicles',
    ];
    for (final t in tables) {
      await db.delete(t);
    }
    await db.rawDelete(
      'DELETE FROM sqlite_sequence WHERE name IN '
      '(${List.filled(tables.length, '?').join(',')})',
      tables,
    );
  }

  // ── Fleet, rentals, maintenance & incidents ────────────────────────────────

  static Future<void> seedFleet(DatabaseExecutor db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime day(int offset) => today.add(Duration(days: offset));
    final ts = now.toIso8601String();

    Future<int> idOf(String table, String column, String value) async {
      final r = await db.query(table,
          columns: ['id'], where: '$column = ?', whereArgs: [value], limit: 1);
      return r.first['id'] as int;
    }

    final agent = await idOf('users', 'email', 'agent@autorent.tn');
    final admin = await idOf('users', 'email', 'admin@autorent.tn');
    final c = <String, int>{
      for (final cl in _clients) cl.$2: await idOf('clients', 'numero_permis', cl.$5)
    };

    // Vehicles + photos copied from the bundled assets
    final v = <String, int>{};
    final rate = <String, double>{};
    for (final (marque, modele, plaque, prix, photo, age) in _fleet) {
      final id = await db.insert('vehicles', {
        'marque': marque,
        'modele': modele,
        'immatriculation': plaque,
        'prix_par_jour': prix,
        'disponible': 1,
        'created_at': day(-age).toIso8601String(),
      });
      final file = await ImageStorage.installAsset('assets/vehicles/$photo.jpg');
      await db.insert('vehicle_photos',
          {'vehicle_id': id, 'file_name': file, 'position': 0});
      v[photo] = id;
      rate[photo] = prix;
    }

    // Rentals: (véhicule, client, agent, début, fin, statut)
    final rentals = <(String, String, int, int, int, String)>[
      ('suzuki_swift', 'Rania', agent, -40, -35, 'terminee'),
      ('suzuki_swift', 'Youssef', agent, -12, -10, 'terminee'),
      ('suzuki_swift', 'Amira', agent, 2, 6, 'reservee'),
      ('skoda_fabia', 'Mohamed', agent, -70, -63, 'terminee'),
      ('skoda_fabia', 'Karim', agent, -3, 2, 'en_cours'),
      ('skoda_fabia', 'Ines', admin, 10, 13, 'annulee'),
      ('dacia_logan', 'Leila', admin, -100, -96, 'terminee'),
      ('dacia_logan', 'Karim', agent, -28, -24, 'terminee'),
      ('dacia_logan', 'Omar', agent, -8, -1, 'en_cours'), // en retard
      ('peugeot_208', 'Ines', agent, -85, -80, 'terminee'),
      ('peugeot_208', 'Rania', admin, -20, -15, 'terminee'),
      ('peugeot_208', 'Youssef', agent, 0, 3, 'reservee'), // départ aujourd'hui
      ('renault_clio', 'Amira', agent, -130, -123, 'terminee'),
      ('renault_clio', 'Mohamed', admin, -45, -42, 'terminee'),
      ('renault_clio', 'Rania', agent, 1, 4, 'reservee'), // conflit entretien
      ('audi_q3', 'Karim', admin, -150, -146, 'terminee'),
      ('audi_q3', 'Leila', agent, -55, -52, 'terminee'),
      ('audi_q3', 'Ines', agent, -4, 0, 'en_cours'), // retour aujourd'hui
      ('audi_q3', 'Omar', agent, 7, 10, 'reservee'),
    ];
    final rentalIds = <int>[];
    for (final (car, client, user, start, end, statut) in rentals) {
      final days = (end - start) < 1 ? 1 : end - start;
      rentalIds.add(await db.insert('rentals', {
        'client_id': c[client],
        'vehicle_id': v[car],
        'user_id': user,
        'date_debut': _iso(day(start)),
        'date_fin': _iso(day(end)),
        'prix_total': days * rate[car]!,
        'statut': statut,
        'created_at': day(start - 3).toIso8601String(),
      }));
    }
    int rentalOf(int index) => rentalIds[index];

    // Maintenance: (véhicule, type, date, statut, description)
    for (final (car, type, offset, statut, desc) in const [
      ('renault_clio', 'Freins', 0, 'en_cours',
          'Remplacement des plaquettes et disques avant.'),
      ('dacia_logan', 'Vidange', 5, 'planifie',
          'Vidange + filtre à huile (15 000 km).'),
      ('suzuki_swift', 'Révision', -30, 'termine', 'Révision des 30 000 km.'),
      ('peugeot_208', 'Pneus', -60, 'termine', 'Remplacement des 4 pneus.'),
      ('audi_q3', 'Révision', -2, 'planifie', 'Révision constructeur annuelle.'),
      ('skoda_fabia', 'Batterie', 12, 'planifie',
          'Contrôle et remplacement de la batterie.'),
    ]) {
      await db.insert('maintenances', {
        'vehicle_id': v[car],
        'type': type,
        'date': _iso(day(offset)),
        'description': desc,
        'statut': statut,
        'created_at': ts,
      });
    }

    // Incidents with their status history (who changed what, and when) and
    // the place picked on the map, so the follow-up dashboard has data.
    DateTime at(int daysAgo, int hour, int minute) {
      final d = day(-daysAgo);
      return DateTime(d.year, d.month, d.day, hour, minute);
    }

    Future<void> incident({
      required String car,
      int? rental,
      required int reportedBy,
      required String type,
      required int daysAgo,
      required String lieu,
      required (double, double) position,
      required String description,
      required List<(String, int, DateTime)> history, // (statut, user, when)
    }) async {
      final id = await db.insert('incidents', {
        'vehicle_id': v[car],
        'rental_id': rental,
        'reported_by_user_id': reportedBy,
        'type': type,
        'date': _iso(day(-daysAgo)),
        'lieu': lieu,
        'latitude': position.$1,
        'longitude': position.$2,
        'description': description,
        'statut': history.last.$1,
        'created_at': history.first.$3.toIso8601String(),
      });
      String? from;
      for (final (statut, user, changedAt) in history) {
        await db.insert('incident_history', {
          'incident_id': id,
          'from_statut': from,
          'to_statut': statut,
          'changed_by_user_id': user,
          'changed_at': changedAt.toIso8601String(),
        });
        from = statut;
      }
    }

    await incident(
      car: 'skoda_fabia',
      rental: rentalOf(4),
      reportedBy: agent,
      type: 'panne',
      daysAgo: 1,
      lieu: 'Route de La Marsa',
      position: (36.8650, 10.3050),
      description: 'Voyant moteur allumé et perte de puissance en côte.',
      history: [('en_attente', agent, at(1, 18, 5))],
    );
    await incident(
      car: 'dacia_logan',
      rental: rentalOf(8),
      reportedBy: agent,
      type: 'panne',
      daysAgo: 2,
      lieu: 'Autoroute A1, sortie Hammamet',
      position: (36.4220, 10.5650),
      description:
          'Crevaison du pneu avant droit, roue de secours montée par le client.',
      history: [
        ('en_attente', agent, at(2, 7, 45)),
        ('en_cours', admin, at(2, 9, 15)),
      ],
    );
    await incident(
      car: 'audi_q3',
      rental: rentalOf(17),
      reportedBy: admin,
      type: 'accident',
      daysAgo: 2,
      lieu: 'Parking Tunisia Mall, Lac 2',
      position: (36.8430, 10.2770),
      description:
          'Rayure profonde sur la portière arrière gauche, constat amiable signé.',
      history: [
        ('en_attente', admin, at(2, 16, 20)),
        ('en_cours', agent, at(1, 9, 0)),
      ],
    );
    await incident(
      car: 'renault_clio',
      reportedBy: agent,
      type: 'panne',
      daysAgo: 3,
      lieu: 'Agence AutoRent, Tunis',
      position: (36.7992, 10.1802),
      description:
          'Bruit de frottement au freinage signalé lors du contrôle de retour.',
      history: [
        ('en_attente', agent, at(3, 10, 15)),
        ('en_cours', admin, at(3, 11, 30)),
        ('resolu', admin, at(1, 15, 0)),
      ],
    );
    await incident(
      car: 'peugeot_208',
      rental: rentalOf(10),
      reportedBy: agent,
      type: 'accident',
      daysAgo: 17,
      lieu: 'Avenue Habib Bourguiba, Tunis',
      position: (36.7999, 10.1860),
      description: 'Choc arrière à un feu rouge. Feu arrière gauche cassé, '
          'constat amiable rempli.',
      history: [
        ('en_attente', agent, at(17, 17, 20)),
        ('en_cours', admin, at(16, 9, 0)),
        ('resolu', admin, at(12, 16, 45)),
      ],
    );
    await incident(
      car: 'suzuki_swift',
      rental: rentalOf(1),
      reportedBy: agent,
      type: 'panne',
      daysAgo: 11,
      lieu: 'Parking Lac 2, Tunis',
      position: (36.8475, 10.2700),
      description:
          'Le véhicule ne démarre plus, batterie à plat. Dépanneuse appelée.',
      history: [
        ('en_attente', agent, at(11, 9, 10)),
        ('en_cours', admin, at(11, 11, 30)),
      ],
    );
    await incident(
      car: 'suzuki_swift',
      rental: rentalOf(0),
      reportedBy: admin,
      type: 'accident',
      daysAgo: 38,
      lieu: 'Sousse centre',
      position: (35.8256, 10.6370),
      description: "Rétroviseur droit cassé lors d'un stationnement.",
      history: [
        ('en_attente', admin, at(38, 17, 20)),
        ('en_cours', admin, at(37, 9, 0)),
        ('resolu', agent, at(33, 16, 45)),
      ],
    );
  }
}
