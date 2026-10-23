# Module 3 — Véhicules

Fleet catalogue: brand, model, plate, daily price, photos, availability.

## Data
Tables `vehicles` + `vehicle_photos`; model `Vehicle` (`brand, model, plate, pricePerDay, available, photos, createdAt`, getter `label`). Repository: `VehicleRepository` — `getAll({availableOnly, search})`, `getById`, `getPhotos`, `insert` / `update` (transaction incl. photos), `delete`, `immatExists(plate, {excludeId})`, `getAvailableForRange(start, end, {excludeRentalId})`, `getAvailabilityState(id)`.

Computed state (`VehicleAvailability` enum, shown as a chip): `enEntretien` (has a maintenance `en_cours`) → `louee` (rental `en_cours` covering today) → `indisponible` (`disponible = 0`) → `disponible`. The stored flag `disponible` is the **manual** switch edited by the user; the chip is computed for display.

## Screens
| Screen | Route | Notes |
|---|---|---|
| `VehiclesTab` | bottom tab 1 | `TabBar`: Tous · Disponibles · Indisponibles (filters on the stored flag) + `SearchField`; body is a **`GridView.builder`** (2 columns) of `VehicleCard`s; FAB → `vehicleForm` |
| `VehicleDetailScreen` | `/vehicles/detail` `IdArgs` | photo carousel (`PageView`, tap a photo → `photoViewer` via `GestureDetector`), brand/model, plate, price/day, availability chip; buttons below |
| `VehicleFormScreen` | `/vehicles/form` `VehicleFormArgs?` | create + edit |
| `MaintenanceHistoryScreen` | `/vehicles/maintenance-history` `IdArgs(vehicleId)` | see `maintenances.md` |

Detail buttons: **Louer ce véhicule** → `rentalForm(RentalFormArgs(vehicleId))` (disabled with a reason when not rentable); **Historique d'entretien** → `maintenanceHistory(IdArgs(vehicleId))`; **Planifier un entretien** → `maintenanceForm(MaintenanceFormArgs(vehicleId))`; AppBar: Modifier, Supprimer. Reload the detail when any pushed screen pops `true`.

## Form fields
| Field | Control | Validation |
|---|---|---|
| Marque | `TextFormField` | required |
| Modèle | `TextFormField` | required |
| Immatriculation | `TextFormField`, `TextCapitalization.characters` | `Validators.plate`, unique (`immatExists`) |
| Prix de location / jour (DT) | decimal keyboard | `Validators.positiveNumber` |
| Disponible | `SwitchListTile` | – |
| Photos | `PhotoPickerField`, max 6, first = cover | optional |

## Access
Full CRUD for every logged-in user.

## Rules
- Photos: copy picked images with `ImageStorage.pickAndSave`; on save, write the list through `replacePhotos` in the same transaction as the vehicle; delete files removed during the edit only after the DB write succeeded; on cancel of a *create* form, delete files picked but never saved.
- Delete: confirm; refused with a friendly message if rentals/incidents exist; on success delete photo files and cascade maintenances.
- Changing the price does not change existing rentals (they store `prix_total`).
- Show prices with `formatMoney`.
