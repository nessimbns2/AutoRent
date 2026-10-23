---
name: autorent-local-storage
description: Offline persistence for AutoRent. Use when creating or changing the SQLite schema, DatabaseHelper, models, repositories, seed data, session handling (shared_preferences), or photo storage; when anything asks about data persistence, "local storage", "no API", or offline behaviour. Everything is stored on the device with sqflite, shared_preferences and the app documents directory; there is never a network call.
---

# AutoRent — local storage

**Rule zero: no network.** No `http`, no sync, no remote DB. If a feature seems to need a server (forgot-password email, image upload, sharing), replace it with a local equivalent and say so in `docs/ARCHITECTURE.md`.

## Three stores, three jobs

| Store | Package | Holds | Why |
|---|---|---|---|
| SQLite `autorent.db` | `sqflite` + `path` | users, clients, vehicles, vehicle_photos, maintenances, rentals, incidents, incident_photos | relational data, foreign keys, queries (course: Séance 5) |
| Key/value | `shared_preferences` | `session_user_id`, `last_tab`, `remember_me` | small, non-critical (course warns not to store critical data here) |
| Files | `path_provider` + `path` + `image_picker` | photo files under `<documents>/photos/` | images must not go into SQLite as blobs |

Hive is **not** used (relational data → SQL).

## Schema

The authoritative DDL is `references/schema.sql`. Execute it from `DatabaseHelper._onCreate` (split statements into a list of strings; sqflite runs one statement per `execute`). Key points:
- `PRAGMA foreign_keys = ON` in `onConfigure`.
- `version: 1`; put migrations in `_onUpgrade(db, oldV, newV)` as `if (oldV < 2) { … }` blocks. Never edit old blocks.
- Delete behaviour: photos and maintenances `ON DELETE CASCADE`; rentals and incidents referencing a vehicle/client are `RESTRICT` (catch `DatabaseException` and show a friendly message).
- Enum-like columns use `CHECK(... IN (...))`.

## DatabaseHelper contract

Singleton `DatabaseHelper.instance`, `Future<Database> get database` (opens lazily, once). Path: `join(await getDatabasesPath(), 'autorent.db')`. `_onCreate` creates the tables, then calls `_seed(db)`. Provide `close()` and (debug only) `resetForDev()` that deletes the file. Full templates: `references/code-templates.md`.

## Models

One class per table in `models/`, immutable fields, `factory X.fromMap(Map<String, Object?>)`, `Map<String, Object?> toMap()` (omit `id` when null), `copyWith`. Enums in `models/enums.dart` with `value` (stored string), `label` (French UI text) and `fromValue`. Dates are `DateTime` in Dart, stored as ISO `yyyy-MM-dd` strings; booleans are `0/1`.

Read-side convenience: repositories may return "view" objects that include joined names (e.g. `RentalView { Rental rental; String clientName; String vehicleLabel; }`) so list screens do one query instead of N+1.

## Repositories

One per entity in `repositories/`, constructed with no arguments, using `DatabaseHelper.instance`. Standard methods: `getAll({filters})`, `getById(id)`, `insert(model) → id`, `update(model)`, `delete(id)`. Always use `where`/`whereArgs` (never string-interpolate user input). Extra methods required by the business rules:

- `UserRepository`: `getByEmail`, `emailExists(email, {excludeId})`, `authenticate(email, password) → User?`, `updatePassword(email, newPassword)`, `count()`.
- `VehicleRepository`: `getPhotos(vehicleId)`, `replacePhotos(vehicleId, fileNames)`, `immatExists(plate, {excludeId})`, `search(text)`, `getAvailabilityState(vehicleId)` (computed: disponible / louée / en entretien / indisponible), `getAvailableForRange(start, end, {excludeRentalId})`.
- `MaintenanceRepository`: `getByVehicle(vehicleId)`, `getViewsByStatus(status) → List<MaintenanceView>`, `hasActiveMaintenance(vehicleId)`.
- `RentalRepository`: `hasOverlap(vehicleId, start, end, {excludeId})`, `getActiveForVehicle(vehicleId, date)`, `changeStatus(id, status)`, `getViewsByStatus(status) → List<RentalView>`, `countByStatus()`.
- `IncidentRepository`: `getPhotos`, `replacePhotos`, `changeStatus`, `getViewsByStatus(status) → List<IncidentView>`, `getByVehicle`.
- `ClientRepository`: `search(text)`, `hasRentals(id)`.

Overlap SQL (reference):
```sql
SELECT COUNT(*) FROM rentals
WHERE vehicle_id = ? AND statut IN ('reservee','en_cours')
  AND date_debut <= ? AND date_fin >= ?   -- args: vehicleId, newEnd, newStart
  AND (? IS NULL OR id != ?);             -- exclude the rental being edited
```

All methods are `async`; screens consume them with `FutureBuilder` (course: Future + FutureBuilder). Wrap multi-table writes (vehicle + photos, incident + photos) in `db.transaction`.

## Session (`core/session/session_manager.dart`)

Singleton holding `User? currentUser`. `init()` reads `session_user_id` from `shared_preferences`, loads the user from SQLite, and clears the key if the user no longer exists. `login(User)` / `logout()` update both the in-memory user and the preference. Exposes `isLoggedIn` (there are no roles). Because `init()` runs in `main()` before `runApp`, router guards can be synchronous. Do not store the password or hash in preferences.

## Photos (`core/services/image_storage.dart`)

- `static Future<void> init()` → resolves `getApplicationDocumentsDirectory()`, creates `photos/`, caches the path.
- `Future<String?> pickAndSave(ImageSource source)` → `ImagePicker().pickImage(source, maxWidth: 1600, imageQuality: 80)`, copies into `photos/` with a unique name (`<timestamp>_<random>.jpg`), returns **only the file name**.
- `File fileFor(String fileName)` → synchronous, so widgets can use `Image.file(ImageStorage.fileFor(name))` without a FutureBuilder.
- `Future<void> delete(String fileName)`.
- **Never store absolute paths**: the iOS app container path changes between installs/updates. Store the file name; resolve at display time.
- When replacing/deleting photos in a form, delete the removed files only **after** the DB write succeeded; delete all files of a vehicle/incident when that record is deleted.
- Always provide `errorBuilder` on `Image.file` (show the placeholder icon).
- iOS `Info.plist`: add `NSPhotoLibraryUsageDescription` and `NSCameraUsageDescription` (French text). Android needs no extra permission for gallery/camera via `image_picker`.

## Seed data (first launch only, inside `_onCreate`)

- Users: one account, `agent@autorent.tn` / `Agent123!` (see `autorent-orchestrator/references/spec.md`); the hash is computed with `PasswordHasher`, never stored in clear in code comments.
- 3 renters, 5 vehicles (no photos — the UI falls back to `assets/images/car_placeholder.png`), 3 maintenances (one per status), 3 rentals (reservee / en_cours / terminee), 2 incidents (accident en_attente, panne resolu).
- Seeds use fixed relative dates computed from `DateTime.now()` so the demo always looks current.

## Async checklist

- `Future<void> _load()` helpers; `late Future<List<X>> _future;` assigned in `initState`, re-assigned inside `setState` to reload.
- Never call `setState` or use `context` after an `await` without `if (!mounted) return;`.
- Catch `DatabaseException` in write paths and translate to French messages (UNIQUE → "Cet email existe déjà", FOREIGN KEY → "Suppression impossible : élément utilisé ailleurs").
