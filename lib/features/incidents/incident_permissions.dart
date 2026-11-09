import '../../core/session/session_manager.dart';

/// Who can do what on incidents.
///
/// The users table has no role column, so the admin is the seeded
/// `admin@autorent.tn` account. Every other account is a regular agent:
/// they can declare, view, edit and delete an incident, but only the
/// admin can change its status or open the statistics.
class IncidentPermissions {
  IncidentPermissions._();

  static const adminEmail = 'admin@autorent.tn';

  static bool get isAdmin =>
      SessionManager.instance.currentUser?.email.trim().toLowerCase() ==
      adminEmail;

  static bool get canChangeStatus => isAdmin;
  static bool get canDelete => true;
  static bool get canSeeStats => isAdmin;
  static bool get canEdit => true;
}
