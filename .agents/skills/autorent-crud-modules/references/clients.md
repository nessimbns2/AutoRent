# Module 2 — Locataires (clients)

Supporting entity added because the brief says rentals are created "en sélectionnant un locataire" and mentions "ses clients" (see decision 1 in `autorent-orchestrator/references/spec.md`). Renters never log in.

## Data
Table `clients`; model `Client` (`lastName, firstName, phone, email?, licenseNumber, createdAt`, getter `fullName`). Repository: `ClientRepository` — `getAll({search})`, `getById`, `insert`, `update`, `delete`, `hasRentals(id)`.

## Screens
| Screen | Route | Notes |
|---|---|---|
| `ClientListScreen` | `/clients` (Drawer) | `ListView.builder`; search by name/phone/permit; FAB → form |
| `ClientDetailScreen` | `/clients/detail` `IdArgs` | contact info + the renter's rentals (small list, tap → `rentalDetail`) + button "Nouvelle location" → `rentalForm(RentalFormArgs(clientId))` |
| `ClientFormScreen` | `/clients/form` `ClientFormArgs?` | create + edit |

## Form fields
| Field | Validation |
|---|---|
| Nom, Prénom | required |
| Téléphone | `Validators.phone` (8–15 digits, spaces/+ allowed) |
| Email | optional; if filled, must match email format |
| Numéro de permis | required |

## Access
Full CRUD for every logged-in user.

## Rules
- Delete refused when the renter has rentals: `AppException('Suppression impossible : ce locataire a des locations.')` (check `hasRentals` first; also catch the FK error).
- When `ClientFormScreen` is opened from the rental form (the "+" next to the renter dropdown), it pops `true`; the rental form reloads the renters and preselects the one with the highest id.
