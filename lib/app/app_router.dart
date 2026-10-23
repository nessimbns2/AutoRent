import 'package:flutter/material.dart';

import '../core/session/session_manager.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/clients/client_detail_screen.dart';
import '../features/clients/client_form_screen.dart';
import '../features/clients/client_list_screen.dart';
import '../features/common/not_found_screen.dart';
import '../features/common/photo_viewer_screen.dart';
import '../features/home/home_shell.dart';
import '../features/incidents/incident_detail_screen.dart';
import '../features/incidents/incident_form_screen.dart';
import '../features/maintenances/maintenance_detail_screen.dart';
import '../features/maintenances/maintenance_form_screen.dart';
import '../features/maintenances/maintenance_history_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/rentals/rental_detail_screen.dart';
import '../features/rentals/rental_form_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/users/user_detail_screen.dart';
import '../features/users/user_form_screen.dart';
import '../features/users/user_list_screen.dart';
import '../features/vehicles/vehicle_detail_screen.dart';
import '../features/vehicles/vehicle_form_screen.dart';
import 'route_args.dart';
import 'routes.dart';

class AppRouter {
  AppRouter._();

  static const _public = {
    Routes.splash,
    Routes.login,
    Routes.register,
    Routes.forgotPassword,
  };

  static Route<dynamic> onGenerateRoute(RouteSettings s) {
    try {
      return _build(s);
    } on TypeError {
      return _bad(s);
    }
  }

  static Route<dynamic> _build(RouteSettings s) {
    final session = SessionManager.instance;

    if (!_public.contains(s.name) && !session.isLoggedIn) {
      return _page(const LoginScreen(), const RouteSettings(name: Routes.login));
    }

    final args = s.arguments;
    switch (s.name) {
      case Routes.splash:
        return _page(const SplashScreen(), s);
      case Routes.login:
        return _page(const LoginScreen(), s);
      case Routes.register:
        return _page(const RegisterScreen(), s);
      case Routes.forgotPassword:
        return _page(const ForgotPasswordScreen(), s);
      case Routes.home:
        return _page(
            HomeShell(
                initialTab: args is HomeArgs ? args.initialTab : 0),
            s);
      case Routes.profile:
        return _page(const ProfileScreen(), s);
      case Routes.users:
        return _page(const UserListScreen(), s);
      case Routes.clients:
        return _page(const ClientListScreen(), s);

      // id-based screens
      case Routes.userDetail:
        return args is IdArgs
            ? _page(UserDetailScreen(userId: args.id), s)
            : _bad(s);
      case Routes.clientDetail:
        return args is IdArgs
            ? _page(ClientDetailScreen(clientId: args.id), s)
            : _bad(s);
      case Routes.vehicleDetail:
        return args is IdArgs
            ? _page(VehicleDetailScreen(vehicleId: args.id), s)
            : _bad(s);
      case Routes.maintenanceHistory:
        return args is IdArgs
            ? _page(MaintenanceHistoryScreen(vehicleId: args.id), s)
            : _bad(s);
      case Routes.maintenanceDetail:
        return args is IdArgs
            ? _page(MaintenanceDetailScreen(maintenanceId: args.id), s)
            : _bad(s);
      case Routes.rentalDetail:
        return args is IdArgs
            ? _page(RentalDetailScreen(rentalId: args.id), s)
            : _bad(s);
      case Routes.incidentDetail:
        return args is IdArgs
            ? _page(IncidentDetailScreen(incidentId: args.id), s)
            : _bad(s);
      case Routes.photoViewer:
        return args is PhotoViewerArgs
            ? _page(
                PhotoViewerScreen(
                    fileNames: args.fileNames,
                    initialIndex: args.initialIndex),
                s)
            : _bad(s);

      // form screens
      case Routes.userForm:
        final a = args as UserFormArgs?;
        return _page(UserFormScreen(userId: a?.userId), s);
      case Routes.clientForm:
        final a = args as ClientFormArgs?;
        return _page(ClientFormScreen(clientId: a?.clientId), s);
      case Routes.vehicleForm:
        final a = args as VehicleFormArgs?;
        return _page(VehicleFormScreen(vehicleId: a?.vehicleId), s);
      case Routes.maintenanceForm:
        final a = args as MaintenanceFormArgs?;
        return _page(
            MaintenanceFormScreen(
                maintenanceId: a?.maintenanceId, vehicleId: a?.vehicleId),
            s);
      case Routes.rentalForm:
        final a = args as RentalFormArgs?;
        return _page(
            RentalFormScreen(
                rentalId: a?.rentalId,
                vehicleId: a?.vehicleId,
                clientId: a?.clientId),
            s);
      case Routes.incidentForm:
        final a = args as IncidentFormArgs?;
        return _page(
            IncidentFormScreen(
                incidentId: a?.incidentId,
                vehicleId: a?.vehicleId,
                rentalId: a?.rentalId),
            s);
    }
    return onUnknownRoute(s);
  }

  static Route<dynamic> onUnknownRoute(RouteSettings s) =>
      _page(NotFoundScreen(routeName: s.name), s);

  static Route<dynamic> _bad(RouteSettings s) => _page(
      NotFoundScreen(
          routeName: s.name,
          message: 'Paramètres de navigation invalides.'),
      s);

  static MaterialPageRoute<dynamic> _page(Widget child, RouteSettings s) =>
      MaterialPageRoute(builder: (_) => child, settings: s);
}
