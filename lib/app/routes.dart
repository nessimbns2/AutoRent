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
