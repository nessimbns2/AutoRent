# Code templates — navigation

Starting points. Keep names; adapt details. All screens are reached with `Navigator.pushNamed`.

## app/routes.dart

```dart
class Routes {
  Routes._();
  // public
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  // authenticated
  static const home = '/home';
  static const profile = '/profile';
  static const photoViewer = '/photo-viewer';
  // users
  static const users = '/users';
  static const userDetail = '/users/detail';
  static const userForm = '/users/form';
  // clients
  static const clients = '/clients';
  static const clientDetail = '/clients/detail';
  static const clientForm = '/clients/form';
  // vehicles
  static const vehicleDetail = '/vehicles/detail';
  static const vehicleForm = '/vehicles/form';
  static const maintenanceHistory = '/vehicles/maintenance-history';
  // maintenances
  static const maintenanceDetail = '/maintenances/detail';
  static const maintenanceForm = '/maintenances/form';
  // rentals
  static const rentalDetail = '/rentals/detail';
  static const rentalForm = '/rentals/form';
  // incidents
  static const incidentDetail = '/incidents/detail';
  static const incidentForm = '/incidents/form';
}
```

## app/route_args.dart

```dart
class HomeArgs { final int initialTab; const HomeArgs({this.initialTab = 0}); }
class IdArgs { final int id; const IdArgs(this.id); }
class UserFormArgs { final int? userId; const UserFormArgs({this.userId}); }
class ClientFormArgs { final int? clientId; const ClientFormArgs({this.clientId}); }
class VehicleFormArgs { final int? vehicleId; const VehicleFormArgs({this.vehicleId}); }
class MaintenanceFormArgs {
  final int? maintenanceId; final int? vehicleId;
  const MaintenanceFormArgs({this.maintenanceId, this.vehicleId});
}
class RentalFormArgs {
  final int? rentalId; final int? vehicleId; final int? clientId;
  const RentalFormArgs({this.rentalId, this.vehicleId, this.clientId});
}
class IncidentFormArgs {
  final int? incidentId; final int? vehicleId; final int? rentalId;
  const IncidentFormArgs({this.incidentId, this.vehicleId, this.rentalId});
}
class PhotoViewerArgs {
  final List<String> fileNames; final int initialIndex;
  const PhotoViewerArgs({required this.fileNames, this.initialIndex = 0});
}
```

## app/app_router.dart

```dart
class AppRouter {
  AppRouter._();

  static const _public = {Routes.splash, Routes.login, Routes.register, Routes.forgotPassword};

  static Route<dynamic> onGenerateRoute(RouteSettings s) {
    final session = SessionManager.instance;

    if (!_public.contains(s.name) && !session.isLoggedIn) {
      return _page(const LoginScreen(), const RouteSettings(name: Routes.login));
    }

    final args = s.arguments;
    switch (s.name) {
      case Routes.splash:          return _page(const SplashScreen(), s);
      case Routes.login:           return _page(const LoginScreen(), s);
      case Routes.register:        return _page(const RegisterScreen(), s);
      case Routes.forgotPassword:  return _page(const ForgotPasswordScreen(), s);
      case Routes.home:
        return _page(HomeShell(initialTab: args is HomeArgs ? args.initialTab : 0), s);
      case Routes.profile:         return _page(const ProfileScreen(), s);
      case Routes.users:           return _page(const UserListScreen(), s);
      case Routes.clients:         return _page(const ClientListScreen(), s);

      // id based screens: wrong arguments -> error screen, never a crash
      case Routes.userDetail:
        return args is IdArgs ? _page(UserDetailScreen(userId: args.id), s) : _bad(s);
      case Routes.clientDetail:
        return args is IdArgs ? _page(ClientDetailScreen(clientId: args.id), s) : _bad(s);
      case Routes.vehicleDetail:
        return args is IdArgs ? _page(VehicleDetailScreen(vehicleId: args.id), s) : _bad(s);
      case Routes.maintenanceHistory:
        return args is IdArgs ? _page(MaintenanceHistoryScreen(vehicleId: args.id), s) : _bad(s);
      case Routes.maintenanceDetail:
        return args is IdArgs ? _page(MaintenanceDetailScreen(maintenanceId: args.id), s) : _bad(s);
      case Routes.rentalDetail:
        return args is IdArgs ? _page(RentalDetailScreen(rentalId: args.id), s) : _bad(s);
      case Routes.incidentDetail:
        return args is IdArgs ? _page(IncidentDetailScreen(incidentId: args.id), s) : _bad(s);
      case Routes.photoViewer:
        return args is PhotoViewerArgs
            ? _page(PhotoViewerScreen(fileNames: args.fileNames, initialIndex: args.initialIndex), s)
            : _bad(s);

      // forms: null arguments = create
      case Routes.userForm:
        return _page(UserFormScreen(userId: (args as UserFormArgs?)?.userId), s);
      case Routes.clientForm:
        return _page(ClientFormScreen(clientId: (args as ClientFormArgs?)?.clientId), s);
      case Routes.vehicleForm:
        return _page(VehicleFormScreen(vehicleId: (args as VehicleFormArgs?)?.vehicleId), s);
      case Routes.maintenanceForm:
        final a = args as MaintenanceFormArgs?;
        return _page(MaintenanceFormScreen(maintenanceId: a?.maintenanceId, vehicleId: a?.vehicleId), s);
      case Routes.rentalForm:
        final a = args as RentalFormArgs?;
        return _page(RentalFormScreen(rentalId: a?.rentalId, vehicleId: a?.vehicleId, clientId: a?.clientId), s);
      case Routes.incidentForm:
        final a = args as IncidentFormArgs?;
        return _page(IncidentFormScreen(incidentId: a?.incidentId, vehicleId: a?.vehicleId, rentalId: a?.rentalId), s);
    }
    return onUnknownRoute(s);
  }

  static Route<dynamic> onUnknownRoute(RouteSettings s) =>
      _page(NotFoundScreen(routeName: s.name), s);

  static Route<dynamic> _bad(RouteSettings s) =>
      _page(NotFoundScreen(routeName: s.name, message: 'Paramètres de navigation invalides.'), s);

  static MaterialPageRoute<dynamic> _page(Widget child, RouteSettings s) =>
      MaterialPageRoute(builder: (_) => child, settings: s);
}
```

Note: `args as XFormArgs?` throws if a wrong type is passed. Wrap the whole `switch` in a `try { … } on TypeError { return _bad(s); }` or use `args is XFormArgs ? args : null`.

## app/app.dart

```dart
class AutoRentApp extends StatelessWidget {
  const AutoRentApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AutoRent',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        initialRoute: Routes.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onUnknownRoute: AppRouter.onUnknownRoute,
      );
}
```

## SplashScreen (decides where to go)

```dart
@override
void initState() {
  super.initState();
  Future.delayed(const Duration(milliseconds: 900), () {
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      SessionManager.instance.isLoggedIn ? Routes.home : Routes.login,
    );
  });
}
```

## Login ↔ Register result passing

```dart
// LoginScreen
Future<void> _openRegister() async {
  final email = await Navigator.pushNamed<String>(context, Routes.register);
  if (email != null && mounted) {
    _emailController.text = email;
    showSnack(context, 'Compte créé. Connectez-vous.');
  }
}
// RegisterScreen after a successful insert:
Navigator.pop(context, _emailController.text.trim());
```

## features/home/home_shell.dart

```dart
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab;
  static const _titles = ['Accueil', 'Véhicules', 'Locations', 'Entretiens', 'Incidents'];

  void _goTo(int i) => setState(() => _index = i);

  Widget _bodyFor(int i) => switch (i) {
        0 => DashboardTab(onGoToTab: _goTo),
        1 => const VehiclesTab(),
        2 => const RentalsTab(),
        3 => const MaintenancesTab(),
        _ => const IncidentsTab(),
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0); // Back on another tab → Accueil
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_titles[_index])),
        drawer: const AppDrawer(),
        body: KeyedSubtree(key: ValueKey(_index), child: _bodyFor(_index)), // rebuilt → re-queries SQLite
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _index,
          onTap: _goTo,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Accueil'),
            BottomNavigationBarItem(icon: Icon(Icons.directions_car_outlined), label: 'Véhicules'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Locations'),
            BottomNavigationBarItem(icon: Icon(Icons.build_outlined), label: 'Entretiens'),
            BottomNavigationBarItem(icon: Icon(Icons.report_problem_outlined), label: 'Incidents'),
          ],
        ),
      ),
    );
  }
}
```

## core/widgets/app_drawer.dart

```dart
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser!;
    void open(String route) {
      Navigator.pop(context);                 // close the drawer first
      Navigator.pushNamed(context, route);
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          InkWell(
            onTap: () => open(Routes.profile),
            child: UserAccountsDrawerHeader(
              accountName: Text('${user.firstName} ${user.lastName}'),
              accountEmail: Text(user.email),
              currentAccountPicture: CircleAvatar(child: Text(user.initials)),
            ),
          ),
          ListTile(leading: const Icon(Icons.person_outline), title: const Text('Mon profil'),
              onTap: () => open(Routes.profile)),
          ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Locataires'),
              onTap: () => open(Routes.clients)),
          ListTile(leading: const Icon(Icons.group_outlined), title: const Text('Utilisateurs'),
              onTap: () => open(Routes.users)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Déconnexion'),
            onTap: () async {
              Navigator.pop(context);
              final ok = await confirmDialog(context,
                  title: 'Déconnexion', message: 'Voulez-vous vraiment vous déconnecter ?');
              if (ok != true || !context.mounted) return;
              await SessionManager.instance.logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
            },
          ),
        ],
      ),
    );
  }
}
```

The drawer content is unmounted when it closes and rebuilt when it opens, so the header shows fresh data as long as `ProfileScreen` calls `SessionManager.instance.refresh()` after saving.

## Tab body with TabBar as filter (pattern for all four module tabs)

```dart
class RentalsTab extends StatefulWidget {
  const RentalsTab({super.key});
  @override
  State<RentalsTab> createState() => _RentalsTabState();
}

class _RentalsTabState extends State<RentalsTab> with SingleTickerProviderStateMixin {
  static const _filters = [RentalStatus.reservee, RentalStatus.enCours, RentalStatus.terminee, RentalStatus.annulee];
  final _repo = RentalRepository();
  late final TabController _tabs = TabController(length: _filters.length, vsync: this);
  late Future<List<RentalView>> _future = _load();

  Future<List<RentalView>> _load() => _repo.getViewsByStatus(_filters[_tabs.index]);
  void _reload() => setState(() => _future = _load());

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _reload();
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _open(String route, Object? args) async {
    final changed = await Navigator.pushNamed<bool>(context, route, arguments: args);
    if (changed == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // nested: only body + FAB, the AppBar is HomeShell's
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(Routes.rentalForm, null),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: [for (final f in _filters) Tab(text: f.label)],
          ),
          Expanded(
            child: FutureBuilder<List<RentalView>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingView();
                if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
                final items = snap.data!;
                if (items.isEmpty) return const EmptyState(message: 'Aucune location.');
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => RentalCard(
                    view: items[i],
                    onTap: () => _open(Routes.rentalDetail, IdArgs(items[i].rental.id!)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

## Detail screen: reload after edit and return "changed" to the list

```dart
class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  bool _changed = false;
  late Future<Vehicle?> _future = _repo.getById(widget.vehicleId);

  Future<void> _edit() async {
    final saved = await Navigator.pushNamed<bool>(
        context, Routes.vehicleForm, arguments: VehicleFormArgs(vehicleId: widget.vehicleId));
    if (saved == true && mounted) {
      _changed = true;
      setState(() => _future = _repo.getById(widget.vehicleId));
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, title: 'Supprimer', message: 'Supprimer ce véhicule ?');
    if (ok != true || !mounted) return;
    try {
      await _repo.delete(widget.vehicleId);
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed); // system Back and AppBar back both land here
      },
      child: Scaffold(/* AppBar with edit + delete, FutureBuilder body */),
    );
  }
}
```

## Photo source bottom sheet (Scaffold bottom sheets from Chapitre 2)

```dart
Future<ImageSource?> pickPhotoSource(BuildContext context) => showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Appareil photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
```
