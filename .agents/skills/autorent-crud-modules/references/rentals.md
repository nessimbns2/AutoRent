# Module 5 — Locations (contrats)

Create, view, edit and cancel rental contracts with start and return dates.

## Data
Table `rentals`; model `Rental` (`clientId, vehicleId, userId?, startDate, endDate, totalPrice, status, createdAt`, getter `days`); enum `RentalStatus` (`reservee` Réservée · `en_cours` En cours · `terminee` Terminée · `annulee` Annulée); `RentalView(rental, clientName, vehicleLabel, userName?)`.
Repository: `RentalRepository` — `getViewsByStatus`, `getViewById`, `getById`, `insert`, `update`, `changeStatus`, `delete`, `hasOverlap(vehicleId, start, end, {excludeId})`, `getActiveForVehicle(vehicleId, date)`, `countByStatus()`.

`days = max(1, endDate − startDate in days)`; `totalPrice = days × vehicle.pricePerDay`, computed in the form and stored.

## Screens
| Screen | Route | Notes |
|---|---|---|
| `RentalsTab` | bottom tab 2 | `TabBar`: Réservées · En cours · Terminées · Annulées (scrollable); cards show renter, vehicle, dates `dd/MM → dd/MM`, total, status chip; FAB → `rentalForm` |
| `RentalDetailScreen` | `/rentals/detail` `IdArgs` | contract sheet: renter (tap → `clientDetail`), vehicle (tap → `vehicleDetail`), dates, days, total, created by, status; action buttons; AppBar: Modifier (only `reservee`/`en_cours`), Supprimer |
| `RentalFormScreen` | `/rentals/form` `RentalFormArgs?` | create + edit |

Detail action buttons by status:
- `reservee` → **Démarrer** (→ `en_cours`), **Annuler** (→ `annulee`)
- `en_cours` → **Terminer** (→ `terminee`), **Annuler**
- any status → **Déclarer un incident** → `incidentForm(IncidentFormArgs(vehicleId, rentalId))`
- `terminee` / `annulee` are read-only (no Modifier); they can still be hard-deleted after confirmation.
Every status change asks for confirmation, then `changeStatus` and reload; pop `true` later.

## Form (order matters)
1. **Locataire** — dropdown of clients + "+" `IconButton` → `clientForm`; on return `true` reload clients and select the highest id. Prefilled from `clientId` arg.
2. **Dates** — one read-only field showing `dd/MM/yyyy → dd/MM/yyyy` using `showDateRangePicker` (first date = today for a new rental; when editing allow the existing start). Validator: both dates chosen.
3. **Véhicule** — dropdown filled by `getAvailableForRange(start, end, excludeRentalId: currentId)` after the dates are chosen (and re-queried whenever the dates change; if the chosen vehicle disappears from the list, clear it with a message). If `vehicleId` is prefilled, keep it selected and validate at save.
4. **Total** — read-only live text: `X jours × price = total`.
5. **Statut** — only when editing (dropdown of allowed transitions).
6. **Enregistrer**.

On save re-run the checks (never trust the dropdown alone):
- vehicle `available`, no active maintenance → else `AppException("Ce véhicule n'est pas disponible.")`
- `hasOverlap(...)` false → else `AppException('Ce véhicule est déjà loué sur cette période.')`
- `endDate >= startDate`.
Set `userId = SessionManager.currentUser.id` on create. After a successful **create**, navigate with `pushReplacementNamed(Routes.rentalDetail, arguments: IdArgs(id), result: true)`; after an **edit** just `pop(true)`.

## Access
Full access for every logged-in user: create, read, update, change status, cancel (*Annuler*) and hard delete (*Supprimer*).

## Rules
- Overlap check ignores `terminee` and `annulee` rentals and the rental being edited.
- Cancelling keeps the record (history); the vehicle becomes rentable again for those dates automatically because overlap ignores cancelled rentals.
- Dashboard counters (`countByStatus`) read from here.
