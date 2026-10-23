---
name: autorent-architecture
description: Architecture for the AutoRent offline Flutter app. Use when creating the project structure, deciding where a file belongs, adding a layer, writing main.dart, pubspec, theme or shared widgets, or producing docs/ARCHITECTURE.md. Defines the layered, feature-first folder layout (screens → repositories → SQLite), dependency rules and naming conventions, kept simple enough for a mobile-dev course.
---

# AutoRent — architecture

Layered + feature-first, **no server tier**. Three layers, one direction of dependency:

```
features/ (screens, widgets)  →  repositories/  →  core/database (sqflite)
            ↓                          ↓
         models/  ←────────────────────┘          core/ (session, services, utils, shared widgets)
```

- **Presentation** (`features/`): screens and widgets. `StatefulWidget` + `setState` + `FutureBuilder`. Calls repositories, never SQL.
- **Data access** (`repositories/`): one class per entity. Owns every SQL query, maps rows ↔ models, enforces business rules that touch the database (overlap check, delete restrictions). Returns `Future<…>`.
- **Storage** (`core/database/`): `DatabaseHelper` opens the single SQLite database (versioned, foreign keys on, seeded on first create). `SessionManager` wraps `shared_preferences`. `ImageStorage` wraps the documents directory.
- **Models** (`models/`): plain Dart classes with `fromMap` / `toMap`, `copyWith`, enums. No Flutter imports.

There is deliberately no service locator, no dependency injection framework and no state-management package: repositories are instantiated where needed (`final _repo = VehicleRepository();`) and share the singleton `DatabaseHelper`.

## Folder layout

```
lib/
  main.dart                        // WidgetsFlutterBinding, init storage + session, runApp
  app/
    app.dart                       // MaterialApp: theme, initialRoute, onGenerateRoute, onUnknownRoute
    theme.dart                     // Material 3 ColorScheme.fromSeed, input/button/card themes
    routes.dart                    // Routes constants (see autorent-navigation)
    route_args.dart                // typed argument classes
    app_router.dart                // onGenerateRoute + guards
  core/
    constants/strings.dart         // French UI strings
    database/database_helper.dart  // open, onCreate, onUpgrade, seed
    session/session_manager.dart   // current user, login/logout (shared_preferences)
    services/image_storage.dart    // pick → copy → file name; resolve; delete
    services/password_hasher.dart  // salted SHA-256
    utils/validators.dart          // required, email, password, plate, phone
    utils/formatters.dart          // dates (dd/MM/yyyy), money (DT)
    utils/app_exception.dart       // AppException(message): thrown by repositories, shown by screens
    utils/ui_helpers.dart          // showSnack, confirmDialog
    widgets/                       // shared: app_drawer, empty_state, status_chip,
                                   // photo_picker_field, photo_strip, section_card,
                                   // search_field, loading_view, error_view
  models/
    enums.dart                     // RentalStatus, MaintenanceStatus, IncidentType, IncidentStatus
    user.dart  client.dart  vehicle.dart  maintenance.dart  rental.dart  incident.dart
  repositories/
    user_repository.dart  client_repository.dart  vehicle_repository.dart
    maintenance_repository.dart  rental_repository.dart  incident_repository.dart
  features/
    splash/        splash_screen.dart
    auth/          login_screen.dart  register_screen.dart  forgot_password_screen.dart
    home/          home_shell.dart  dashboard_tab.dart
    profile/       profile_screen.dart
    users/         user_list_screen.dart  user_detail_screen.dart  user_form_screen.dart
    clients/       client_list_screen.dart  client_detail_screen.dart  client_form_screen.dart
    vehicles/      vehicles_tab.dart  vehicle_detail_screen.dart  vehicle_form_screen.dart  widgets/vehicle_card.dart
    maintenances/  maintenances_tab.dart  maintenance_detail_screen.dart  maintenance_form_screen.dart  maintenance_history_screen.dart
    rentals/       rentals_tab.dart  rental_detail_screen.dart  rental_form_screen.dart
    incidents/     incidents_tab.dart  incident_detail_screen.dart  incident_form_screen.dart
    common/        not_found_screen.dart  photo_viewer_screen.dart
assets/
  images/ logo.png  car_placeholder.png
docs/
  ARCHITECTURE.md
```

Only deviate from this layout with a reason written in `docs/ARCHITECTURE.md`.

## Dependency rules

1. `models/` imports only Dart core libraries.
2. `core/` never imports `features/`. It imports `repositories/` only in `core/session/session_manager.dart` (to restore the logged-in user); `core/database` seeds with plain SQL, not repositories.
3. `repositories/` import `models/` and `core/database`. They never import Flutter UI.
4. `features/` import `repositories/`, `models/`, `core/`, `app/routes.dart` and `app/route_args.dart`. A feature never imports another feature's *screen file* — it navigates with `Navigator.pushNamed(Routes.x, arguments: …)`. (Sharing small widgets goes through `core/widgets/`.)
5. `app/` wires everything; it may import screens (router) but nothing imports `app_router.dart` except `app.dart`.

## Conventions

- Files `snake_case.dart`; classes `PascalCase`; screens end with `Screen`, tab bodies with `Tab`.
- Database columns are French snake_case exactly as in the schema (`prix_par_jour`); Dart fields are English camelCase (`pricePerDay`). The mapping between the two lives only in each model's `fromMap` / `toMap`.
- One screen per file; extract a widget into its own file when a screen passes ~250 lines.
- `const` constructors wherever possible; `super.key`.
- Strings shown to the user live in `strings.dart`; no hardcoded French in widgets except trivial punctuation.
- Dates stored as ISO-8601 `yyyy-MM-dd` text (rental, maintenance, incident dates) and `created_at` as full ISO timestamp.
- Money stored as `REAL` TND, formatted with `NumberFormat`.

## main.dart (shape)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;   // open + create + seed
  await ImageStorage.init();                // cache documents dir path
  await SessionManager.instance.init();     // restore logged-in user (shared_preferences + DB)
  runApp(const AutoRentApp());
}
```

`AutoRentApp` is a `StatelessWidget` returning `MaterialApp(theme: buildTheme(), initialRoute: Routes.splash, onGenerateRoute: AppRouter.onGenerateRoute, onUnknownRoute: AppRouter.onUnknownRoute, debugShowCheckedModeBanner: false)`.

## Theme

Material 3, seed colour orange `Color(0xFFEE7A4C)` (matches the course workshop screenshots), rounded 12 px inputs with outlined border, full-width rounded `ElevatedButton` for primary actions, `Card` with 12 px radius and subtle elevation. Keep a single `buildTheme()` in `app/theme.dart`; screens do not hardcode colours (use `Theme.of(context).colorScheme`). Status chips use a small `StatusChip(label, color)` widget with semantic colours defined once.

## Required deliverable: docs/ARCHITECTURE.md

At the end of the project, write it from `references/diagrams.md` (Mermaid diagrams: layers, ER model, navigation graph) plus a short paragraph per layer, the access rule (login guard only, no roles), and the list of decisions (renters entity, local password reset, no payments, no admin). It must match the code actually generated.
