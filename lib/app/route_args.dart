class HomeArgs {
  final int initialTab;
  const HomeArgs({this.initialTab = 0});
}

class IdArgs {
  final int id;
  const IdArgs(this.id);
}

class UserFormArgs {
  final int? userId;
  const UserFormArgs({this.userId});
}

class ClientFormArgs {
  final int? clientId;
  const ClientFormArgs({this.clientId});
}

class VehicleFormArgs {
  final int? vehicleId;
  const VehicleFormArgs({this.vehicleId});
}

class MaintenanceFormArgs {
  final int? maintenanceId;
  final int? vehicleId;
  const MaintenanceFormArgs({this.maintenanceId, this.vehicleId});
}

class RentalFormArgs {
  final int? rentalId;
  final int? vehicleId;
  final int? clientId;
  const RentalFormArgs({this.rentalId, this.vehicleId, this.clientId});
}

class IncidentFormArgs {
  final int? incidentId;
  final int? vehicleId;
  final int? rentalId;
  const IncidentFormArgs({this.incidentId, this.vehicleId, this.rentalId});
}

class PhotoViewerArgs {
  final List<String> fileNames;
  final int initialIndex;
  const PhotoViewerArgs({required this.fileNames, this.initialIndex = 0});
}
