-- AutoRent — SQLite schema, version 1
-- Execute each statement separately from DatabaseHelper._onCreate.
-- onConfigure must run: PRAGMA foreign_keys = ON;

CREATE TABLE users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  nom           TEXT NOT NULL,
  prenom        TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,            -- "<salt>:<sha256 hex>"
  photo_file    TEXT,                     -- optional avatar file name
  created_at    TEXT NOT NULL             -- ISO-8601 timestamp
);

CREATE TABLE clients (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  nom           TEXT NOT NULL,
  prenom        TEXT NOT NULL,
  telephone     TEXT NOT NULL,
  email         TEXT,
  numero_permis TEXT NOT NULL,
  created_at    TEXT NOT NULL
);

CREATE TABLE vehicles (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  marque         TEXT NOT NULL,
  modele         TEXT NOT NULL,
  immatriculation TEXT NOT NULL UNIQUE,
  prix_par_jour  REAL NOT NULL CHECK (prix_par_jour > 0),
  disponible     INTEGER NOT NULL DEFAULT 1 CHECK (disponible IN (0,1)),
  created_at     TEXT NOT NULL
);

CREATE TABLE vehicle_photos (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  file_name  TEXT NOT NULL,
  position   INTEGER NOT NULL DEFAULT 0   -- first photo (position 0) is the cover
);
CREATE INDEX idx_vehicle_photos_vehicle ON vehicle_photos(vehicle_id);

CREATE TABLE maintenances (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  vehicle_id  INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,              -- vidange | pneus | freins | revision | autre
  date        TEXT NOT NULL,              -- yyyy-MM-dd
  description TEXT,
  statut      TEXT NOT NULL DEFAULT 'planifie'
              CHECK (statut IN ('planifie','en_cours','termine')),
  created_at  TEXT NOT NULL
);
CREATE INDEX idx_maintenances_vehicle ON maintenances(vehicle_id);

CREATE TABLE rentals (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id   INTEGER NOT NULL REFERENCES clients(id)  ON DELETE RESTRICT,
  vehicle_id  INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
  user_id     INTEGER REFERENCES users(id) ON DELETE SET NULL,   -- user who created the contract
  date_debut  TEXT NOT NULL,              -- yyyy-MM-dd
  date_fin    TEXT NOT NULL,              -- yyyy-MM-dd, >= date_debut
  prix_total  REAL NOT NULL,
  statut      TEXT NOT NULL DEFAULT 'reservee'
              CHECK (statut IN ('reservee','en_cours','terminee','annulee')),
  created_at  TEXT NOT NULL,
  CHECK (date_fin >= date_debut)
);
CREATE INDEX idx_rentals_vehicle ON rentals(vehicle_id, date_debut, date_fin);
CREATE INDEX idx_rentals_client  ON rentals(client_id);

CREATE TABLE incidents (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  vehicle_id          INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
  rental_id           INTEGER REFERENCES rentals(id) ON DELETE SET NULL,
  reported_by_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  type                TEXT NOT NULL CHECK (type IN ('accident','panne')),
  date                TEXT NOT NULL,      -- yyyy-MM-dd
  lieu                TEXT NOT NULL,
  description         TEXT NOT NULL,
  statut              TEXT NOT NULL DEFAULT 'en_attente'
                      CHECK (statut IN ('en_attente','en_cours','resolu')),
  created_at          TEXT NOT NULL
);
CREATE INDEX idx_incidents_vehicle ON incidents(vehicle_id);

CREATE TABLE incident_photos (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  incident_id INTEGER NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
  file_name   TEXT NOT NULL,
  position    INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX idx_incident_photos_incident ON incident_photos(incident_id);
