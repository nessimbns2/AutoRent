# Module 6 — Incidents et pannes

Quick declaration of an accident or breakdown on a rented vehicle, with place, description and photos, and follow-up of its status.

## Data
Tables `incidents` + `incident_photos`; model `Incident` (`vehicleId, rentalId?, reportedByUserId?, type, date, place, description, status, photos, createdAt`); enums `IncidentType` (`accident` Accident · `panne` Panne) and `IncidentStatus` (`en_attente` En attente · `en_cours` En cours · `resolu` Résolu); `IncidentView(incident, vehicleLabel, reporterName?)`.
Repository: `IncidentRepository` — `getViewsByStatus`, `getById`, `getPhotos`, `insert` / `update` (transaction incl. photos), `changeStatus`, `delete`, `getByVehicle`.

The renter has no account; the logged-in user declares the incident for them (decision 3 in `spec.md`). Make this fast: few required fields, big buttons.

## Screens
| Screen | Route | Notes |
|---|---|---|
| `IncidentsTab` | bottom tab 4 | `TabBar`: En attente · En cours · Résolus; cards show type icon (car-crash / build), vehicle, date, place, status chip; FAB → `incidentForm` |
| `IncidentDetailScreen` | `/incidents/detail` `IdArgs` | type, vehicle (tap → `vehicleDetail`), linked rental (tap → `rentalDetail`), date, place, description, photos (`PhotoStrip` → `photoViewer`), declared by; status buttons (Prendre en charge → `en_cours`, Marquer résolu → `resolu`); AppBar: Modifier, Supprimer |
| `IncidentFormScreen` | `/incidents/form` `IncidentFormArgs?` | create + edit |

## Form fields
| Field | Control | Validation |
|---|---|---|
| Type | `SegmentedButton<IncidentType>` (Accident / Panne) | required, default Panne |
| Véhicule | dropdown of all vehicles (locked when `vehicleId` is prefilled) | required |
| Location liée | read-only info: after vehicle + date are set, look up `RentalRepository.getActiveForVehicle(vehicleId, date)`; show "Location #id — nom du locataire" and store `rental_id`, otherwise "Aucune location active" and store null (prefilled `rentalId` wins) | – |
| Date | `showDatePicker`, not in the future | required |
| Lieu | `TextFormField` | required |
| Description | multiline | required, ≥ 10 chars |
| Photos | `PhotoPickerField`, max 5 | optional |
| Statut | dropdown, **edit only** (create always starts `en_attente`) | required |

`reportedByUserId` = current user on create (not editable).

## Access
Full CRUD for every logged-in user, including status changes.

## Rules
- Deleting an incident deletes its photo files (after the DB delete succeeded); photo rows cascade.
- Declaring an incident does not change the vehicle's availability automatically; the user can plan a maintenance from the vehicle detail ("Planifier un entretien").
- Status flow `en_attente → en_cours → resolu`; editing may move it back.
- Dashboard shows the number of incidents `en_attente`.
