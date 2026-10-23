# Route table

`Routes` constant → path → screen → arguments → guard → result.

| Constant | Path | Screen | Arguments | Guard | Pops with |
|---|---|---|---|---|---|
| `splash` | `/` | `SplashScreen` | – | public | – (replaced) |
| `login` | `/login` | `LoginScreen` | – | public | – |
| `register` | `/register` | `RegisterScreen` | – | public | `String` email on success |
| `forgotPassword` | `/forgot-password` | `ForgotPasswordScreen` | – | public | `String` email on success |
| `home` | `/home` | `HomeShell` | `HomeArgs?` (`initialTab`) | auth | – |
| `profile` | `/profile` | `ProfileScreen` | – | auth | `true` if profile changed (Drawer header refreshes) |
| `users` | `/users` | `UserListScreen` | – | auth | – |
| `userDetail` | `/users/detail` | `UserDetailScreen` | `IdArgs` | auth | `true` if edited/deleted |
| `userForm` | `/users/form` | `UserFormScreen` | `UserFormArgs?` | auth | `true` if saved |
| `clients` | `/clients` | `ClientListScreen` | – | auth | – |
| `clientDetail` | `/clients/detail` | `ClientDetailScreen` | `IdArgs` | auth | `true` if edited/deleted |
| `clientForm` | `/clients/form` | `ClientFormScreen` | `ClientFormArgs?` | auth | `true` if saved |
| `vehicleDetail` | `/vehicles/detail` | `VehicleDetailScreen` | `IdArgs` | auth | `true` if edited/deleted/changed |
| `vehicleForm` | `/vehicles/form` | `VehicleFormScreen` | `VehicleFormArgs?` | auth | `true` if saved |
| `maintenanceHistory` | `/vehicles/maintenance-history` | `MaintenanceHistoryScreen` | `IdArgs` (vehicle id) | auth | `true` if something changed |
| `photoViewer` | `/photo-viewer` | `PhotoViewerScreen` | `PhotoViewerArgs` | auth | – |
| `maintenanceDetail` | `/maintenances/detail` | `MaintenanceDetailScreen` | `IdArgs` | auth | `true` if edited/deleted/status changed |
| `maintenanceForm` | `/maintenances/form` | `MaintenanceFormScreen` | `MaintenanceFormArgs?` | auth | `true` if saved |
| `rentalDetail` | `/rentals/detail` | `RentalDetailScreen` | `IdArgs` | auth | `true` if edited/cancelled/deleted/status changed |
| `rentalForm` | `/rentals/form` | `RentalFormScreen` | `RentalFormArgs?` | auth | `true` if saved (or replaced by detail) |
| `incidentDetail` | `/incidents/detail` | `IncidentDetailScreen` | `IdArgs` | auth | `true` if edited/deleted/status changed |
| `incidentForm` | `/incidents/form` | `IncidentFormScreen` | `IncidentFormArgs?` | auth | `true` if saved |

Guard legend: *public* = reachable without a session; *auth* = needs a logged-in user (otherwise the router shows Login). There are no roles.

## Argument classes (`app/route_args.dart`)

| Class | Fields |
|---|---|
| `HomeArgs` | `int initialTab = 0` |
| `IdArgs` | `int id` |
| `UserFormArgs` | `int? userId` |
| `ClientFormArgs` | `int? clientId` |
| `VehicleFormArgs` | `int? vehicleId` |
| `MaintenanceFormArgs` | `int? maintenanceId`, `int? vehicleId` (prefill) |
| `RentalFormArgs` | `int? rentalId`, `int? vehicleId` (prefill), `int? clientId` (prefill) |
| `IncidentFormArgs` | `int? incidentId`, `int? vehicleId` (prefill), `int? rentalId` (prefill) |
| `PhotoViewerArgs` | `List<String> fileNames`, `int initialIndex` |

All are `const` classes with named parameters. A form screen receives its args object's fields as constructor parameters (e.g. `VehicleFormScreen(vehicleId: args?.vehicleId)`).

## Bottom-bar tabs (inside `/home`)

| Index | Label | Icon | Body widget | FAB opens |
|---|---|---|---|---|
| 0 | Accueil | `Icons.dashboard_outlined` | `DashboardTab` | – |
| 1 | Véhicules | `Icons.directions_car_outlined` | `VehiclesTab` | `vehicleForm` |
| 2 | Locations | `Icons.assignment_outlined` | `RentalsTab` | `rentalForm` |
| 3 | Entretiens | `Icons.build_outlined` | `MaintenancesTab` | `maintenanceForm` |
| 4 | Incidents | `Icons.report_problem_outlined` | `IncidentsTab` | `incidentForm` |

## Drawer items

| Item | Visible to | Action |
|---|---|---|
| Header (initials avatar, full name, email) | all | tap → `profile` |
| Mon profil | all | `pushNamed(Routes.profile)` |
| Locataires | all | `pushNamed(Routes.clients)` |
| Utilisateurs | all | `pushNamed(Routes.users)` |
| Déconnexion | all | confirm → logout → `pushNamedAndRemoveUntil(login)` |
