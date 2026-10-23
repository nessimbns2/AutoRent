# Module 4 — Entretiens des véhicules

Keeps the maintenance history of every car.

## Data
Table `maintenances`; model `Maintenance` (`vehicleId, type, date, description?, status, createdAt`); enum `MaintenanceStatus` (`planifie` Planifié · `en_cours` En cours · `termine` Terminé); `MaintenanceView` adds `vehicleLabel`. Types (plain strings from a constant list in `strings.dart`): Vidange, Pneus, Freins, Révision, Batterie, Autre.
Repository: `MaintenanceRepository` — `getByVehicle(vehicleId)`, `getViewsByStatus(status)`, `getById`, `insert`, `update`, `changeStatus`, `delete`, `hasActiveMaintenance(vehicleId)`.

## Screens
| Screen | Route | Notes |
|---|---|---|
| `MaintenancesTab` | bottom tab 3 | `TabBar`: Planifiés · En cours · Terminés; `ListView.builder` of cards (vehicle label, type, date, status chip); FAB → `maintenanceForm` |
| `MaintenanceDetailScreen` | `/maintenances/detail` `IdArgs` | vehicle (tap → `vehicleDetail`), type, date, description, status; status buttons (Démarrer → `en_cours`, Terminer → `termine`); AppBar: Modifier, Supprimer |
| `MaintenanceFormScreen` | `/maintenances/form` `MaintenanceFormArgs?` | create + edit; `vehicleId` prefill locks the vehicle dropdown |
| `MaintenanceHistoryScreen` | `/vehicles/maintenance-history` `IdArgs(vehicleId)` | AppBar title = vehicle label; chronological `ListView.builder` (newest first) with a simple timeline look; FAB → `maintenanceForm(vehicleId)` |

## Form fields
| Field | Control | Validation |
|---|---|---|
| Véhicule | `DropdownButtonFormField<int>` of all vehicles | required |
| Type d'entretien | dropdown of the type list | required |
| Date | read-only field + `showDatePicker` | required |
| Description | multiline `TextFormField`, optional | max 500 chars |
| Statut | dropdown (default Planifié) | required |

## Access
Full CRUD for every logged-in user, including status changes.

## Rules
- A vehicle with a maintenance in status `en_cours` is "En entretien": badge on its card/detail and excluded from rental vehicle choices.
- Status order `planifie → en_cours → termine`; allow correcting backwards through the edit form.
- Deleting a maintenance never touches the vehicle.
