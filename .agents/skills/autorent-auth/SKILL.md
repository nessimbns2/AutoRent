---
name: autorent-auth
description: Local authentication and session for the offline AutoRent app. Single type of user, no admin and no roles. Use when building or changing Login, Register, Forgot password, Profile, password hashing, the session, or the "must be logged in" route guard. Accounts live in SQLite, the session in shared_preferences; once logged in, a user can use every feature.
---

# AutoRent — authentication (no roles)

Everything is local. There is no token, no backend, no email. Read `autorent-local-storage` for `SessionManager`, `PasswordHasher` and `UserRepository`, and `autorent-navigation` for the redirects after login/logout.

## Principle

- **One kind of user.** No admin, no agent role, no `role` column, no `Permissions` class, no "access denied" screen. Every logged-in user can do everything in every module.
- **One access rule only:** public routes (`splash`, `login`, `register`, `forgotPassword`) work without a session; every other route needs a logged-in user. The router enforces it; screens do not repeat it.
- Authentication exists to identify who is using the device and to keep the data behind a login, not to separate privileges.

## Screens

Style follows the course workshop (Sign In / Sign Up screens): logo on top, title, outlined fields, orange full-width primary button, small text links. Use `Form` + `GlobalKey<FormState>` + `TextFormField` with validators (Chapitre 4). Validation errors appear under the field (French).

### LoginScreen (`/login`)
- Fields: email, mot de passe (obscured, eye icon toggles).
- Buttons: **Se connecter** (`ElevatedButton`), **Créer un compte** and **Mot de passe oublié ?** (`TextButton`).
- Flow: `validate()` → `UserRepository.authenticate(email, password)` → `null` ⇒ SnackBar "Email ou mot de passe incorrect" → else `SessionManager.login(user)` → `pushReplacementNamed(Routes.home)`.
- Disable the button while the check runs (`_loading`), `if (!mounted) return;` after the await.
- Email lookup is case-insensitive (`LOWER(email)`); password comparison uses `PasswordHasher.verify`.

### RegisterScreen (`/register`)
- Fields: nom, prénom, email, mot de passe, confirmation.
- Creates the account; the user can log in immediately. Email must be unique ("Cet email existe déjà").
- Success: optional `AlertDialog` "Compte créé" (the course workshop shows an information dialog), then `Navigator.pop(context, email)` so Login pre-fills it.

### ForgotPasswordScreen (`/forgot-password`)
- Fields: email, nouveau mot de passe, confirmation.
- Local reset: if the email exists, `UserRepository.updatePassword`; otherwise "Aucun compte avec cet email". Pops with the email.
- State in the README that a real app would send a mail; this offline version resets directly (fine for the course project, not for production).

### ProfileScreen (`/profile`)
- Shows avatar (initials, or the user's photo via `ImageStorage`), nom, prénom, email.
- Editable: nom, prénom, email (unique check excluding self), optional photo, and a **change password** section (current password required, new password + confirmation) — this mirrors the "Modifier profil" screen of the course workshop.
- Saves through `UserRepository.update`, then `SessionManager.refresh()` and `Navigator.pop(context, true)`.

Managing *other* accounts (list, add, edit, delete) is the Users module: `autorent-crud-modules/references/users.md`.

## Account rules (enforced in `UserRepository`)

- Emails are unique, case-insensitive.
- Passwords: minimum 6 characters; stored as `"<salt>:<sha256>"` via `PasswordHasher`; never logged, never put in `shared_preferences`.
- The last remaining account cannot be deleted → `AppException('Au moins un compte doit exister')`.
- If the logged-in user deletes their own account, log out right after and go to Login with `pushNamedAndRemoveUntil`.
- Deleting a user referenced by rentals/incidents sets those references to `NULL` (schema `ON DELETE SET NULL`); lists must tolerate a missing user ("Utilisateur supprimé").

## Session

`SessionManager` (in `autorent-local-storage`) holds `User? currentUser` and exposes only `isLoggedIn`, `login`, `logout`, `refresh`. It restores the session in `main()` from `shared_preferences`, so the router guard is synchronous and the app opens directly on Home after a restart.

## Seed account

`agent@autorent.tn` / `Agent123!` (created on first launch with demo data). Show it in the README, not on the login screen.

## Quick tests

1. Wrong password → error, stays on Login. 2. Register → returns to Login with the email filled, then login works. 3. Kill and relaunch → still logged in. 4. Logout → Back does not reopen the app content. 5. Forgot password → old password no longer works, new one does. 6. Deleting the last account is refused.
