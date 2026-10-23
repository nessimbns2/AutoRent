# Course map — what the slides teach and where AutoRent uses it

Source: the five course decks (Chapitre 2 widgets de base, Chapitre 3 ListView/GridView/Stateless-Stateful, Chapitre 4 Forms et Navigation, Séance 5 Stockage local, Séance 6 HTTP).

## Chapitre 2 — widgets de base
| Slide concept | Use in AutoRent |
|---|---|
| `Scaffold` (drawers, snack bars, bottom sheets) | every screen; `HomeShell` hosts AppBar + Drawer + BottomNavigationBar |
| `AppBar` | titles, actions (edit, delete menu) |
| `Column`, `Row`, `Center`, `Container` | layout of cards, detail screens, empty states |
| `Text`, `Image` | labels; vehicle photos via `Image.file` (local) and `Image.asset` for the logo/placeholder |
| `ElevatedButton` | primary actions (Se connecter, Enregistrer) |
| `FlatButton` → **removed from Flutter**, use `TextButton` | secondary actions (Annuler, Mot de passe oublié) |
| `Card` | list items, dashboard tiles |

## Chapitre 3 — listes et widgets à état
| Slide concept | Use in AutoRent |
|---|---|
| `ListView.builder` (`itemCount`, `itemBuilder`) | users, renters, rentals, maintenances, incidents |
| `GridView.builder` | vehicles catalogue (2 columns, photo cards) |
| `ListView(children: …)` / `GridView.count` (small fixed lists) | dashboard quick actions, photo thumbnails strip |
| `StatelessWidget` | cards, badges, empty-state, status chips (state comes from the constructor) |
| `StatefulWidget` + `setState` | tabs, forms, filters, anything with internal state |
| Rule from the slides: start Stateless, switch to Stateful when internal state is needed | follow it |

## Chapitre 4 — formulaires et navigation
| Slide concept | Use in AutoRent |
|---|---|
| `TextField` (`onChanged`, `onSubmitted`) | search bars in lists |
| `TextFormField` + `Form` + `GlobalKey<FormState>` (`validate()`, `save()`, `reset()`) | every create/edit form and the auth screens |
| `GestureDetector` | long-press on list items for quick actions, tap on a photo to enlarge it |
| `InkWell` (ink splash) | tappable `Card`s that open a detail screen |
| `Navigator.push` / `pushReplacement` / `pop` | simple jumps where no name is needed (e.g. photo viewer) |
| `Navigator.pushNamed` / `pushReplacementNamed` / `pop` with **arguments** (`ScreenArguments` example) | all detail/form screens, login → home, splash |
| `Drawer` | profile header, Mon profil, Locataires, Utilisateurs, Déconnexion |
| `BottomNavigationBar` | Accueil · Véhicules · Locations · Entretiens · Incidents |
| `TabBar` (+ `TabBarView`, `DefaultTabController`) | status filters inside each module tab |
| Workshop navigation map: Authentification → Inscription / Mot de passe oublié / Accueil → Store, Bibliothèque, Panier, Modifier profil | mirrored by AutoRent's map in `autorent-navigation` |

## Séance 5 — stockage local
| Slide concept | Use in AutoRent |
|---|---|
| `shared_preferences` (key/value, non-critical data) | logged-in user id, "remember me", last selected tab |
| `sqflite` (SQL, versioned open, helper methods `query/insert/update/delete`, background thread) | all business data |
| `package:path` (`join`, `getDatabasesPath`) | database file path, photo paths |
| Hive | **not used** — data is relational (rentals ↔ vehicles ↔ renters); sqflite fits better and the slides present it as the SQL option |
| `async` / `await`, `Future<T>`, `FutureBuilder(future:, builder: (context, snapshot) {})` | every repository call and every list/detail screen |

## Séance 6 — HTTP
Read for background only. **Not used**: no `http`, no REST, no JSON API. `dart:convert` is allowed only for local serialisation if a screen really needs it (it normally does not).

## Style rules derived from the course
- Prefer plain, readable widgets over clever abstractions. A student must be able to explain every file.
- Comments: short, in English, explaining *why*; do not narrate obvious code.
- One concept per file; screens call repositories directly (no extra layers beyond those in `autorent-architecture`).
