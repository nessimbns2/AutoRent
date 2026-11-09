# User module - changes

Copy the files in this zip over the project (same relative paths), then run:

    flutter pub get      # new dependencies: qr_flutter (2FA QR code), pdf (report)
    flutter analyze
    flutter test
    flutter run

The database goes from version 1 to 2; existing installs migrate automatically
(old data is kept). If you already ran an earlier copy of this module, UNINSTALL
the app / delete its database once, so the final v2 schema is created cleanly.

## What it does (everything works offline)
- Password reset with a RECOVERY KEY (XXXX-XXXX-XXXX-XXXX), shown once, with a
  "Copier" button; only its salted hash is stored. Single-use: a new key is
  issued after each reset. The email on the reset form only identifies the account.
- Colleague reset (forgotten password, no key): user detail -> "Reinitialiser le
  mot de passe": the colleague types the new password. No forced change.
- Creating a user from the Users screen: the agent types the password, as before.
- TWO-FACTOR AUTH (TOTP, RFC 6238): Profil -> Securite du compte -> "Activer la
  2FA": QR code + manual key, confirm with a 6-digit code. Works with Google /
  Microsoft Authenticator, Authy, or a desktop/browser authenticator. At login,
  after the password, a 6-digit code is asked. Codes cannot be replayed; +-30 s
  clock drift is tolerated. The PC/phone clock must be correct.
  - Lost phone: "Mot de passe oublie" with the recovery key also switches 2FA off,
    or a colleague can use "Desactiver sa 2FA" on the user's detail screen.
  - Disabling your own 2FA requires a valid code.
- PDF USER REPORT: "Exporter le rapport (PDF)" on a user's detail screen, and
  "Exporter mon rapport (PDF)" in Profil -> Securite du compte. A4 report with
  profile + photo, security status (2FA, recovery key, lockout), last-30-days
  activity, business activity (contracts created / in progress / completed,
  revenue excluding cancellations, incidents reported - read-only from the
  rentals and incidents tables) and the last 25 activity events, multi-page with
  page numbers. Saved to the Downloads folder (desktop) or the app's external
  folder (Android); on desktop an "Ouvrir" button opens it in the default PDF
  viewer. It never contains passwords, hashes, recovery keys or 2FA secrets.
  Each export is recorded in the user's activity log.
- Login lockout: 5 failures (password, recovery key or 2FA code) -> 1 min,
  doubling each failure, max 15 min.
- Activity log per user, in "Profil -> Securite du compte" and on the user detail.
- Password rules for NEW passwords: 8+ chars, letter + digit, strength meter.
  (Login keeps its old lighter check so existing accounts still work.)

## Shared files touched (see shared_files.diff, optional reading)
- lib/core/database/database_helper.dart  (v2: 5 columns on users + user_activity table)
- lib/app/routes.dart                     (2 new route names)
- lib/app/app_router.dart                 (2 new routes + recovery-key guard on home)
- lib/core/session/session_manager.dart   (logs logout)
- pubspec.yaml                            (qr_flutter, pdf)
Teammates' tables (rentals, incidents) are only READ by the PDF report.

## Notes for teammates
- No existing columns renamed or removed; users.id / users.email unchanged.
- Demo accounts have no recovery key yet: on first login they are asked to save one.
