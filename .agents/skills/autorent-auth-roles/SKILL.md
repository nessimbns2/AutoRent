---
name: autorent-auth-roles
description: Authentication, session and role-based access for the offline AutoRent app. Use when building or changing Login, Register, Forgot password, Profile, password hashing, the Permissions class, or anything that shows/hides features for admin vs agent. No server: accounts live in SQLite, the session in shared_preferences.
---

# AutoRent — authentication and roles

Everything is local. There is no token, no backend, no email. Read `autorent-local-storage` for `SessionManager`, `PasswordHasher` and `UserRepository`, and `autorent-navigation` for the redirects after login/logout.

## Screens

Style follows the course workshop (Sign In / Sign Up screens): logo on top, title, outlined fields, orange full-width primary button, small text links. Use `Form` + `GlobalKey<FormState>` + `TextFormField` with validators (Chapitre 4). Validation errors appear under the field (French).

### LoginScreen (`/login`)
- Fields: email, mot de passe (obscured, eye icon toggles).
- Buttons: **Se connecter** (`ElevatedButton`), **Créer un compte** and **Mot de passe oublié ?** (`TextButton`).
- Flow: `validate()` → `UserRepository.authenticate(email, password)` → `null` ⇒ SnackBar "Email ou mot de passe incorrect" → else `SessionManager.login(user)` → `pushReplacementNamed(Routes.home)`.
- Disable the button while the check runs (`_loading`), `if (!mounted) return;` after the await.
- Comparing hashes uses `PasswordHasher.verify`; email lookup is case-insensitive (`LOWER(email)`).

### RegisterScreen (`/register`)
- Fields: nom, prénom, email, mot de passe, confirmation.
- Creates a user with role **agent** (the role cannot be chosen here — only an admin picks roles in the Users module). Email must be unique.
- Success: optional `AlertDialog` "Compte créé" (the course workshop shows an information dialog), then `Navigator.pop(context, email)` so Login pre-fills it.

### ForgotPasswordScreen (`/forgot-password`)
- Fields: email, nouveau mot de passe, confirmation.
- Local reset: if the email exists, `UserRepository.updatePassword`; otherwise "Aucun compte avec cet email". Pops with the email.
- Document in the README that a real app would send a mail; this offline version resets directly (acceptable for the course project, not for production).

### ProfileScreen (`/profile`, any logged-in user)
- Shows avatar (initials, or the user's photo via `ImageStorage`), nom, prénom, email, role (read-only chip).
- Editable: nom, prénom, email (unique check excluding self), optional photo, and **change password** section (current password required, new password + confirmation).
- Saves through `UserRepository.update`, then `SessionManager.refresh()` and `Navigator.pop(context, true)`.
- This is the only users-related screen an agent can open.

## Roles and permissions

Roles: `UserRole.admin`, `UserRole.agent` (`models/enums.dart`). Permission matrix: `autorent-orchestrator/references/spec.md`.

`core/session/permissions.dart`:

```dart
class Permissions {
  Permissions._();
  static bool get _isAdmin => SessionManager.instance.isAdmin;

  static bool get canManageUsers => _isAdmin;        // list/create/edit/delete users
  static bool get canEditVehicles => _isAdmin;       // create/update/delete vehicles
  static bool get canDeleteClients => _isAdmin;
  static bool get canDeleteMaintenances => _isAdmin;
  static bool get canDeleteRentals => _isAdmin;      // hard delete; "Annuler" is open to agents
  static bool get canDeleteIncidents => _isAdmin;
}
```

Usage rules:
- **Hide, don't disable.** Agents simply do not see FABs, edit/delete icons or Drawer entries they cannot use.
- Router guard (`AppRouter`) is the safety net for admin-only routes.
- Repositories do not check roles (they are pure data access); the UI and router do.

## Account safety rules (enforced in `UserRepository` / Users screens)

- An admin cannot delete their own account from the Users module.
- The last remaining admin cannot be deleted or demoted (`countAdmins() > 1` check) — show "Il doit rester au moins un administrateur".
- Emails are unique (case-insensitive); show "Cet email existe déjà".
- Passwords: minimum 6 characters; stored as `"<salt>:<sha256>"` via `PasswordHasher`; never logged, never put in `shared_preferences`.
- Deleting a user referenced by rentals/incidents sets those references to `NULL` (schema `ON DELETE SET NULL`); lists must tolerate `agent_id == null` ("Utilisateur supprimé").

## Seed accounts

`admin@autorent.tn` / `Admin123!` and `agent@autorent.tn` / `Agent123!`. Show them in the README, not on the login screen.

## Tests to run mentally (or with the emulator)

1. Wrong password → error, stays on Login. 2. Register → returns to Login with the email filled. 3. Login as agent → Drawer has no "Utilisateurs", vehicle screens have no add/edit/delete. 4. Kill and relaunch → still logged in. 5. Logout → Back does not reopen the app content.
