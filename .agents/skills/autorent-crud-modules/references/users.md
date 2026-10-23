# Module 1 — Utilisateurs

Accounts of the people who use the app. There is **one type of user** (no admin, no roles): every logged-in user can list, add, edit and delete accounts. Own-profile editing with password change lives in `/profile` (see `autorent-auth`).

## Data
Table `users`; model `User` (`lastName, firstName, email, passwordHash, photoFile, createdAt`, getters `fullName`, `initials`). Repository: `UserRepository` — `getAll({search})`, `getById`, `getByEmail`, `emailExists(email, {excludeId})`, `authenticate`, `insert(user, plainPassword)`, `update(user)`, `updatePassword(email, plain)`, `delete(id)`, `count()`.

## Screens
| Screen | Route | Notes |
|---|---|---|
| `UserListScreen` | `/users` (Drawer) | `ListView.builder`; search by name/email; initials avatar; "Vous" tag on the current user; FAB → form |
| `UserDetailScreen` | `/users/detail` `IdArgs` | avatar, nom, prénom, email, date de création; AppBar actions: Modifier, Supprimer; action "Réinitialiser le mot de passe" (dialog asking for a new password) |
| `UserFormScreen` | `/users/form` `UserFormArgs?` | create + edit |

## Form fields
| Field | Control | Validation |
|---|---|---|
| Nom | `TextFormField` | required |
| Prénom | `TextFormField` | required |
| Email | `TextFormField`, `TextInputType.emailAddress` | required, format, unique (`emailExists`) |
| Mot de passe | obscured; **create only** (on edit use the reset action) | ≥ 6 chars |

There is no role field.

## Rules
- The last remaining account cannot be deleted → `AppException('Au moins un compte doit exister')`.
- Deleting the **current** user is allowed after a confirmation that says so; afterwards `SessionManager.logout()` and `pushNamedAndRemoveUntil(Routes.login, (_) => false)`.
- Editing the current user's name/email → call `SessionManager.refresh()` after saving so the Drawer header updates.
- Deleting a user: confirmation dialog; rentals/incidents that referenced them keep working (reference becomes `NULL`).

## Navigation hooks
List card → `userDetail(IdArgs)` → edit → `userForm(UserFormArgs(userId))` → pops `true` → detail reloads and pops `true` to the list.
