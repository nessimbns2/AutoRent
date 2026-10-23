# AutoRent — brief and decisions

## Original brief (from the course project statement)

**AutoRent — Application de gestion de location de voitures.**
Application permettant à une agence de location de voitures de gérer son parc automobile, ses clients, ses contrats et les règlements.
Utilisateurs : Administrateur et agent de location *(see decision 5: simplified to a single type of user)*.
Objectif : numériser la gestion d'une agence de location de véhicules.

| # | Gestion | Fonctionnalités CRUD |
|---|---|---|
| 1 | **Utilisateurs** — comptes, authentification et profils | **Ajouter** : créer un compte (nom, prénom, email, mot de passe, ~~rôle~~). **Consulter** : liste des utilisateurs et profils. **Modifier** : informations personnelles et données du profil. **Supprimer** : supprimer un compte. |
| 2 | **Véhicules** — modèle, immatriculation, prix, photos, disponibilité | **Ajouter** : marque, modèle, immatriculation, prix de location, photos, disponibilité. **Consulter** : liste et caractéristiques. **Modifier** : informations, photos, prix, disponibilité. **Supprimer** : retirer un véhicule. |
| 3 | **Entretiens des véhicules** — historique d'entretien de chaque voiture | **Ajouter** : véhicule, type d'entretien, date, description. **Consulter** : liste + historique par véhicule. **Modifier** : informations ou statut. **Supprimer** : supprimer un entretien. |
| 4 | **Locations** — créer, consulter, modifier, annuler des contrats avec dates de départ et retour | **Ajouter** : locataire + véhicule + dates début/fin. **Consulter** : liste + détails du contrat. **Modifier** : dates, véhicule, statut. **Supprimer** : supprimer ou annuler. |
| 5 | **Incidents et pannes** — le locataire déclare rapidement un problème | **Ajouter** : véhicule, type (accident ou panne), date, lieu, description, photos. **Consulter** : déclarations + détails. **Modifier** : informations ou statut (en attente, en cours, résolu). **Supprimer** : supprimer une déclaration. |

## Extra requirements from the student

- **No server, no API consumption.** Everything is stored locally on the device.
- **Authentication with local storage, and no admin**: a single type of user, no roles.
- **Add an architecture** (documented and reflected in the code).
- **Focus on navigation.**
- Must follow what the course teaches (chapters: widgets de base, ListView/GridView/Stateless-Stateful, Forms & Navigation, Stockage local).

## Decisions where the brief is ambiguous (apply these defaults)

1. **"Locataire" / "clients".** The brief mentions clients and "sélectionner un locataire" but lists no client CRUD. Decision: add a small supporting entity **Locataire (client)** — fields `nom, prénom, téléphone, email, numéro de permis` — with CRUD reachable from the Drawer. Rentals and incidents reference it. Renters do **not** log in. (If the teacher refuses a 6th entity, a rental can store the renter name as free text instead; keep this isolated in `client_repository.dart` and the rental form.)
2. **"Règlements" (payments)** appear in the intro sentence but not in the CRUD table. Out of scope. The rental stores a computed `prix_total` only. Mention this in the README as a possible extension.
3. **Incident declaration.** The renter has no account, so the **logged-in user declares the incident on behalf of the renter** from the Incidents tab or from a rental detail ("Déclarer un incident"). The form records who entered it (`reported_by_user_id`).
4. **"Supprimer ou annuler une location"** → two actions available to every user: *Annuler* (status becomes `annulee`, record kept) and *Supprimer* (hard delete, with confirmation).
5. **No admin, no roles.** The student asked for authentication without an admin. There is a single type of user (an agent de location). The `role` field of the brief is dropped: no `role` column, no permission checks, no admin-only screens. Every logged-in user has full access to every module.
6. **Passwords** are stored as salted SHA-256 hashes (never plain text). "Mot de passe oublié" is a local reset (email + new password) because there is no mail server; document this limitation.
7. **Currency** is TND, displayed as `120,000 DT`/day style via `intl` (`NumberFormat`), stored as `REAL`.

## Access rule

| Route type | Rule |
|---|---|
| Public: `splash`, `login`, `register`, `forgotPassword` | reachable without a session |
| Everything else | requires a logged-in user; otherwise the router shows Login |

No per-module or per-action permissions.

## Business rules

- A vehicle can be rented only if: `disponible = 1`, it has no `en_cours` maintenance, and it has no overlapping rental (`reservee` or `en_cours`) on the chosen dates.
- `date_fin >= date_debut`; number of days = `max(1, date_fin − date_debut in days)`; `prix_total = days × vehicle.prix_par_jour` (snapshot saved on the rental).
- Rental status flow: `reservee → en_cours → terminee`, or `annulee` from `reservee`/`en_cours`.
- Maintenance status: `planifie → en_cours → termine`. A vehicle with an `en_cours` maintenance shows an "En entretien" badge and cannot be selected for a new rental.
- Incident status: `en_attente → en_cours → resolu`.
- Deleting a vehicle that has rentals or incidents is refused with a clear message; its photos and maintenances are deleted with it.
- Deleting a renter that has rentals is refused with a clear message.
- Email is unique among users; immatriculation is unique among vehicles. The last user account cannot be deleted.
- Default account created on first launch: `agent@autorent.tn` / `Agent123!`, plus 4–6 demo vehicles, 3 renters, a few maintenances/rentals/incidents so the UI is not empty.
