---
name: autorent-navigation
description: Navigation design and implementation for AutoRent (Flutter Navigator 1.0). Use before writing ANY screen, and whenever adding a route, passing arguments between screens, building the Drawer / BottomNavigationBar / TabBar, handling Back, login/logout flows, the login route guard, or refreshing a list after returning from another screen. Covers named routes with typed arguments, the HomeShell, the full route table and the back-stack rules from the course (Chapitre 4: Navigator, Drawer, BottomNavigationBar, TabBar).
---

# AutoRent — navigation

Navigation is the part of the project that is graded hardest, so build it first (phase 3) and keep it boringly consistent. Everything here uses what Chapitre 4 teaches: `Navigator` with **named routes + arguments**, `Drawer`, `BottomNavigationBar`, `TabBar`.

Reference files:
- `references/route-table.md` — every route, its screen, arguments, guard and result.
- `references/code-templates.md` — `routes.dart`, `route_args.dart`, `app_router.dart`, `HomeShell`, `AppDrawer`, TabBar list pattern, detail/form result pattern.

## The map

```
Splash ─┬─(no session)→ Login ─┬→ Register          (pop returns the email → prefill Login)
        │                      ├→ Forgot password   (pop returns the email)
        │                      └─(success, pushReplacementNamed)→ Home
        └─(session)──────────────────────────────→ Home

Home = HomeShell: AppBar + Drawer + BottomNavigationBar (5 tabs, built one at a time)
  0 Accueil   dashboard counters + quick actions
  1 Véhicules TabBar: Tous · Disponibles · Indisponibles   (GridView)
  2 Locations TabBar: Réservées · En cours · Terminées · Annulées
  3 Entretiens TabBar: Planifiés · En cours · Terminés
  4 Incidents TabBar: En attente · En cours · Résolus
  Drawer: header (name, email) · Mon profil · Utilisateurs · Locataires · Déconnexion

Pushed above the shell (full-screen routes): *detail* and *form* screens of every module,
Profile, Clients list, Users list, maintenance history, photo viewer.
```

Cross-module links (these demonstrate argument passing — implement all):
- Vehicle detail → **Louer ce véhicule** → `rentalForm(vehicleId)`; → **Historique d'entretien** → `maintenanceHistory(id)`; → **Planifier un entretien** → `maintenanceForm(vehicleId)`.
- Rental detail → **Déclarer un incident** → `incidentForm(vehicleId, rentalId)`; → vehicle name tap → `vehicleDetail`; → renter name tap → `clientDetail`.
- Incident detail → vehicle tap → `vehicleDetail`.
- Dashboard tiles → switch bottom tab (callback) or open a form route.

## Rules

1. **Every screen is reached through a named route.** `Navigator.pushNamed(context, Routes.x, arguments: …)`. No `MaterialPageRoute` in feature code. (Dialogs and bottom sheets use `showDialog` / `showModalBottomSheet`.)
2. **Route names live in `Routes`** (`app/routes.dart`); **argument classes live in `app/route_args.dart`**. No string literals like `'/login'` anywhere else.
3. **One router.** `AppRouter.onGenerateRoute` builds screens from `settings.name` + `settings.arguments`, keeps `settings` on the route, and applies guards. Screens receive their data through **constructor parameters** (the router unpacks the arguments), not through `ModalRoute.of(context)`.
4. **Pass ids, not whole objects**, to detail/form screens; the screen loads the entity from SQLite so there is a single source of truth. Pass extra optional hints for prefill (`vehicleId`, `rentalId`, …).
5. **A form route with `arguments: null` means "create"**; with an id it means "edit". Same screen, same file.
6. **Return values**: a form pops `true` after a successful save; a detail screen pops `true` if anything changed (edited/deleted/status changed). Callers do
   `final changed = await Navigator.pushNamed<bool>(…); if (changed == true && mounted) _reload();`
   Never rely on `.then()` chains or on `didPopNext`.
7. **Entering and leaving the authenticated area**
   - Splash → `pushReplacementNamed` to Login or Home (Splash must never be reachable with Back).
   - Login success → `pushReplacementNamed(Routes.home)`.
   - Logout → confirm dialog → `SessionManager.logout()` → `pushNamedAndRemoveUntil(Routes.login, (_) => false)` so Back cannot return to protected screens.
   - Register / Forgot password are pushed on top of Login and `pop` with the email as result.
8. **Back behaviour on Home**: `PopScope(canPop: _index == 0, …)` — Back on a non-Accueil tab goes to Accueil; Back on Accueil exits the app.
9. **Drawer**: close it first (`Navigator.pop(context)`) and then `pushNamed`, otherwise Back reopens the drawer. Highlight nothing — the drawer only opens pushed pages, the bottom bar owns the tabs.
10. **BottomNavigationBar**: `type: BottomNavigationBarType.fixed` (5 items), icons + short French labels. **Build only the selected tab** (`KeyedSubtree(key: ValueKey(_index), child: _bodyFor(_index))`, no `IndexedStack`) so a tab re-queries SQLite each time it is shown and never displays stale data after a rental/maintenance changed vehicle availability.
11. **TabBar inside each module tab** is a *filter*, not separate pages: use a `TabController` (`SingleTickerProviderStateMixin`) and one list below it that reloads when the selected index changes. This avoids the stale-page problem of `TabBarView` and keeps one `FutureBuilder` per tab. Each tab body owns a nested `Scaffold` with only `body` and `floatingActionButton` (the AppBar belongs to `HomeShell`).
12. **Guards** (in `AppRouter`):
    - not logged in and route not public → Login screen route;
    - wrong/missing arguments for an id-based route → `NotFoundScreen` with a message (never crash on a cast).
    There is a single access rule: logged in or not. No roles.
13. **Unknown route** → `onUnknownRoute` → `NotFoundScreen`.
14. **After creating a rental from a vehicle detail**, go to the new contract with `Navigator.pushReplacementNamed(context, Routes.rentalDetail, arguments: IdArgs(newId), result: true)` so Back returns to the vehicle (and the vehicle detail reloads because `result: true` completes the original `await`).
15. **Async gaps**: after any `await` (dialog, navigation result, repository call) check `if (!mounted) return;` before touching `context`.
16. **Deprecated APIs**: use `PopScope` (not `WillPopScope`), `Navigator.pushNamed<T>`, `Color.withValues`.

## No roles

There are no roles or permissions: every logged-in user sees every Drawer entry, FAB and delete button. The only guard is login (see `autorent-auth`).

## Checklist before moving on from phase 3

- `flutter run` shows Splash → Login; the seeded account can log in and lands on Home with 5 working tabs (placeholder bodies are fine).
- Drawer items open placeholder pages and Back returns correctly; Logout returns to Login and Back does not re-enter Home.
- Without a session, a debug button that calls `Navigator.pushNamed(context, Routes.vehicleDetail, arguments: const IdArgs(1))` redirects to Login.
