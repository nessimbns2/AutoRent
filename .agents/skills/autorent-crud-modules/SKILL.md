---
name: autorent-crud-modules
description: CRUD modules of AutoRent — Utilisateurs, Locataires (clients), Véhicules, Entretiens, Locations, Incidents et pannes. Use when creating or changing any list, detail or form screen, a model/repository for these entities, validation, status changes, photo handling, or business rules (overlap check, delete restrictions). Gives the shared screen patterns and one reference file per module with fields, screens, actions and rules. There are no roles: every logged-in user has full access.
---

# AutoRent — CRUD modules

Each module is a **vertical slice**: model → repository → list → detail → form → routes. Build them in this order (later ones depend on earlier ones):

1. Users → 2. Clients (locataires) → 3. Vehicles → 4. Maintenances → 5. Rentals → 6. Incidents.

Before starting a module read its file in `references/`, plus `references/screen-patterns.md` once. Navigation and arguments come from `autorent-navigation`; tables and repositories from `autorent-local-storage`; login and session from `autorent-auth`.

| Module | Reference | Where the list lives | Screens (files under `features/<module>/`) |
|---|---|---|---|
| Utilisateurs | `references/users.md` | Drawer → `/users` page | `user_list_screen`, `user_detail_screen`, `user_form_screen` |
| Locataires | `references/clients.md` | Drawer → `/clients` page | `client_list_screen`, `client_detail_screen`, `client_form_screen` |
| Véhicules | `references/vehicles.md` | bottom tab 1 | `vehicles_tab`, `vehicle_detail_screen`, `vehicle_form_screen`, `widgets/vehicle_card` |
| Entretiens | `references/maintenances.md` | bottom tab 3 | `maintenances_tab`, `maintenance_detail_screen`, `maintenance_form_screen`, `maintenance_history_screen` |
| Locations | `references/rentals.md` | bottom tab 2 | `rentals_tab`, `rental_detail_screen`, `rental_form_screen` |
| Incidents | `references/incidents.md` | bottom tab 4 | `incidents_tab`, `incident_detail_screen`, `incident_form_screen` |

## Model field names (Dart ↔ column)

| Model | Dart fields ← columns |
|---|---|
| `User` | `lastName`←nom, `firstName`←prenom, `email`, `passwordHash`←password_hash, `photoFile`←photo_file, `createdAt`; getters `fullName`, `initials` |
| `Client` | `lastName`←nom, `firstName`←prenom, `phone`←telephone, `email?`, `licenseNumber`←numero_permis, `createdAt`; getter `fullName` |
| `Vehicle` | `brand`←marque, `model`←modele, `plate`←immatriculation, `pricePerDay`←prix_par_jour, `available`←disponible, `photos` (file names), `createdAt`; getter `label` ("Peugeot 208 · 123 TUN 4567") |
| `Maintenance` | `vehicleId`, `type`, `date`, `description?`, `status`, `createdAt` |
| `Rental` | `clientId`, `vehicleId`, `userId?`←user_id, `startDate`←date_debut, `endDate`←date_fin, `totalPrice`←prix_total, `status`←statut, `createdAt`; getter `days` |
| `Incident` | `vehicleId`, `rentalId?`, `reportedByUserId?`, `type`, `date`, `place`←lieu, `description`, `status`←statut, `photos`, `createdAt` |
| Views | `RentalView(rental, clientName, vehicleLabel, userName?)`, `MaintenanceView(maintenance, vehicleLabel)`, `IncidentView(incident, vehicleLabel, reporterName?)` — built with SQL `JOIN`s |

## Every module must provide

- **Create** (FAB on the list → form with `arguments: null`).
- **Read**: list (search + status filter where the module has statuses), detail screen with all fields.
- **Update**: edit icon on detail → same form with the id; status shortcuts where relevant.
- **Delete** (or *cancel* for rentals): confirmation dialog, friendly error if the DB refuses (`AppException`), pop `true` so the list refreshes.
- Full access for every logged-in user: no role checks, no hidden buttons.
- Empty state, loading state, error state (with retry) for every `FutureBuilder`.
- SnackBar feedback after create/update/delete ("Véhicule ajouté", …).

## UI conventions

- List items: `Card` + `InkWell` (tap → detail); long-press via `GestureDetector`/`InkWell.onLongPress` opens a bottom sheet with quick actions (Modifier / Supprimer).
- Lists: `ListView.builder`; vehicles: `GridView.builder` (2 columns, `childAspectRatio` ≈ 0.78).
- Search: `TextField` with `onChanged` → reload (small debounce not required at this scale).
- Status chips: one `StatusChip` widget; colours — orange = en attente/réservée/planifié, blue = en cours, green = terminée/résolu/terminé/disponible, red = annulée/accident/indisponible, grey = neutral.
- Dates shown `dd/MM/yyyy`; money `120,000 DT` (3 decimals are normal for the dinar but 2 are fine — be consistent).
- Forms: scrollable (`SingleChildScrollView` + `SafeArea`), primary **Enregistrer** button at the bottom, `TextInputAction.next` between fields, correct `keyboardType`, controllers disposed.
- Never put SQL in widgets; never call repositories from `build()` (only from `initState`/event handlers; keep the `Future` in a field).
- Keep text in `strings.dart` when reused; short one-off labels may stay inline.

## Done when (per module)

CRUD works end-to-end on the emulator, data persists after restart, `flutter analyze` is clean, and the module's cross-links from `autorent-navigation` work.
