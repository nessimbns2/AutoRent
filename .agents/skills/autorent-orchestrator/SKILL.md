---
name: autorent-orchestrator
description: Master skill for AutoRent, the offline Flutter car-rental management app built for the ESPRIT mobile development course. Use it whenever the user asks to generate, continue, review or fix AutoRent ("build the project", "car rental app", "AutoRent", "gestion de location de voitures"). It fixes the hard constraints (100% offline, local storage only, no API or http, course-only widgets, navigation first), the build order, the definition of done, and tells you which other autorent-* skills to load.
---

# AutoRent — orchestrator

AutoRent digitalises a car-rental agency: fleet, renters, maintenance history, rental contracts and incident reports. One type of user (an agent de location) who logs in with a local account — **no admin, no roles**. It is a **mobile course project**, so the code must look like what the course teaches (see `references/course-map.md`), not like a production architecture with extra libraries.

## Hard constraints (never break these)

1. **No server, no API.** Do not add `http`, `dio`, Firebase, Supabase, REST/JSON endpoints, or the `INTERNET` permission. Nothing is fetched or synced. Everything lives on the device:
   - business data → **sqflite** (`autorent.db`)
   - session + small preferences → **shared_preferences**
   - photos → copied into the app documents directory (only the file name is stored in SQLite)
2. **Course-aligned code only.** State = `StatefulWidget` + `setState` + `FutureBuilder`. No Provider, Riverpod, Bloc, GetX, MobX, go_router, auto_route. Widgets and patterns come from chapters 2–5 (`references/course-map.md`). Chapter 6 (HTTP) is intentionally **not used**.
3. **Navigation is the centrepiece.** Navigator 1.0 with named routes and typed arguments, plus Drawer + BottomNavigationBar + TabBar, and a login route guard. Load `autorent-navigation` before writing any screen.
4. **Package whitelist** (add with `flutter pub add`, never hardcode old versions):
   `sqflite`, `path`, `path_provider`, `shared_preferences`, `image_picker`, `crypto`, `intl`.
   Anything else needs a one-line justification in `docs/ARCHITECTURE.md`; default answer is "no".
5. **Language.** UI text in French (centralised in `core/constants/strings.dart`). Code identifiers, comments and file names in English. DB columns follow `references/schema.sql` in `autorent-local-storage`.
6. **Target Android and iOS only** (that is what sqflite covers in the course). Do not target web.
7. **No deprecated APIs.** `FlatButton` (shown in the slides) no longer exists → `TextButton`. `WillPopScope` → `PopScope`. `Color.withOpacity` → `withValues(alpha: …)`. `useMaterial3: true`.
8. **Authentication without roles.** One type of user, local accounts in SQLite, no admin, no `role` column, no permission checks. Every logged-in user can do everything; the only guard is "logged in or not".

## Skills to load

| Need | Skill |
|---|---|
| Folder layout, layers, dependency rules, `docs/ARCHITECTURE.md` | `autorent-architecture` |
| SQLite schema, `DatabaseHelper`, repositories, session, photos, seed data | `autorent-local-storage` |
| Routes, arguments, guards, Drawer, BottomNavigationBar, TabBar, back-stack rules | `autorent-navigation` |
| Login / register / forgot password, profile, hashing, session, login guard | `autorent-auth` |
| CRUD for the 5 modules (+ renters), list/form/detail patterns, validation, business rules | `autorent-crud-modules` |

Read the relevant skill **before** creating the files it covers. Full original brief and the decisions taken where it is ambiguous: `references/spec.md`.

## Build order

Do the phases in order. After each phase run `flutter analyze` (must be clean) and, if an emulator is available, run the app and exercise what was just built.

0. **Project bootstrap** — if no Flutter project exists: `flutter create --org tn.esprit --project-name autorent --platforms android,ios .`; add whitelisted packages; remove the counter demo; add iOS `Info.plist` photo/camera usage strings.
1. **Core** — theme, strings, validators, password hasher, `SessionManager`, `ImageStorage`, shared widgets (`autorent-architecture`, `autorent-local-storage`).
2. **Database + models + repositories** for all entities (`autorent-local-storage`). Seed the default account and demo data.
3. **Navigation skeleton** — `Routes`, `RouteArgs`, `AppRouter` with guards, Splash, `HomeShell` (AppBar + Drawer + BottomNavigationBar) with placeholder tabs (`autorent-navigation`).
4. **Authentication** — Login, Register, Forgot password, Profile (`autorent-auth`).
5. **Modules, in dependency order**: Users → Clients (renters) → Vehicles → Maintenances → Rentals → Incidents (`autorent-crud-modules`). Each module = list (tab or page), detail, form, delete/cancel, filters.
6. **Dashboard + cross-module navigation** — counters, quick actions, "Louer ce véhicule", "Historique d'entretien", "Déclarer un incident" shortcuts that pass arguments between screens.
7. **QA + docs** — walk through `references/qa-checklist.md`, fix issues, write `docs/ARCHITECTURE.md` (diagrams in `autorent-architecture/references/diagrams.md`) and a short `README.md` (how to run, default login).

## Working style

- Do not stop to ask questions. Where the brief is ambiguous, apply the default recorded in `references/spec.md` and note any new decision in `docs/ARCHITECTURE.md`.
- Build vertical slices (model → repository → screens → route) so the app runs after every phase.
- Reuse shared widgets instead of copy-pasting the same Card/Form code six times.
- After every `await` that is followed by `context` use, check `if (!mounted) return;`.
- Keep files small: one screen per file, one repository per entity.

## Definition of done

- `flutter analyze` reports no issues; the app builds and launches on Android.
- Airplane-mode test: every feature works with no network; `pubspec.yaml` has no networking package and `AndroidManifest.xml` has no `INTERNET` permission in `main` (the debug manifest may keep it).
- All five modules support create, read, update, delete (cancel for rentals) with validation and confirmations.
- Data survives killing and restarting the app; the session survives too (Splash goes straight to Home).
- Authentication works fully offline (register, login, forgot password, profile); protected screens cannot be opened without a session; there is no role or admin logic anywhere.
- Drawer, BottomNavigationBar and TabBar are all used, named routes with arguments are used for every detail/form screen, and Back behaves predictably (see `autorent-navigation`).
- `docs/ARCHITECTURE.md` and `README.md` exist and match the code.
