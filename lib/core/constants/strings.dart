/// Central repository of all French UI strings.
/// Screens import this file and use the constants; no hardcoded strings in widgets.
class Strings {
  Strings._();

  // App
  static const appName = 'AutoRent';
  static const loading = 'Chargement…';
  static const retry = 'Réessayer';
  static const cancel = 'Annuler';
  static const confirm = 'Confirmer';
  static const save = 'Enregistrer';
  static const edit = 'Modifier';
  static const delete = 'Supprimer';
  static const add = 'Ajouter';
  static const yes = 'Oui';
  static const no = 'Non';
  static const confirmDelete = 'Cette action est définitive.';
  static const noData = 'Aucun résultat.';

  // Auth
  static const login = 'Se connecter';
  static const logout = 'Déconnexion';
  static const logoutConfirm = 'Voulez-vous vraiment vous déconnecter ?';
  static const createAccount = 'Créer un compte';
  static const forgotPassword = 'Mot de passe oublié ?';
  static const email = 'Email';
  static const password = 'Mot de passe';
  static const lastName = 'Nom';
  static const firstName = 'Prénom';
  static const confirmPassword = 'Confirmer le mot de passe';
  static const wrongCredentials = 'Email ou mot de passe incorrect.';
  static const accountCreated = 'Compte créé. Connectez-vous.';

  // Users
  static const users = 'Utilisateurs';
  static const userAdded = 'Utilisateur ajouté';
  static const userUpdated = 'Utilisateur modifié';
  static const userDeleted = 'Utilisateur supprimé';
  static const lastAccountError = 'Au moins un compte doit exister.';
  static const emailExists = 'Cet email existe déjà.';

  // Clients
  static const clients = 'Locataires';
  static const clientAdded = 'Locataire ajouté';
  static const clientUpdated = 'Locataire modifié';
  static const clientDeleted = 'Locataire supprimé';
  static const clientHasRentals = 'Suppression impossible : ce locataire a des locations.';

  // Vehicles
  static const vehicles = 'Véhicules';
  static const vehicleAdded = 'Véhicule ajouté';
  static const vehicleUpdated = 'Véhicule modifié';
  static const vehicleDeleted = 'Véhicule supprimé';
  static const vehicleHasRentals = 'Suppression impossible : ce véhicule a des locations ou des incidents.';
  static const plateExists = 'Cette immatriculation existe déjà.';

  // Maintenances
  static const maintenances = 'Entretiens';
  static const maintenanceAdded = 'Entretien ajouté';
  static const maintenanceUpdated = 'Entretien modifié';
  static const maintenanceDeleted = 'Entretien supprimé';
  static const maintenanceTypes = [
    'Vidange',
    'Pneus',
    'Freins',
    'Révision',
    'Batterie',
    'Autre',
  ];

  // Rentals
  static const rentals = 'Locations';
  static const rentalAdded = 'Location créée';
  static const rentalUpdated = 'Location modifiée';
  static const rentalDeleted = 'Location supprimée';
  static const rentalOverlap = 'Ce véhicule est déjà loué sur cette période.';
  static const vehicleNotAvailable = "Ce véhicule n'est pas disponible.";
  static const vehicleInMaintenance = "Ce véhicule est en entretien.";

  // Incidents
  static const incidents = 'Incidents';
  static const incidentAdded = 'Incident déclaré';
  static const incidentUpdated = 'Incident modifié';
  static const incidentDeleted = 'Incident supprimé';

  // Navigation
  static const home = 'Accueil';
  static const profile = 'Mon profil';
  static const myProfile = 'Mon profil';

  // Generic FK error
  static const fkError = 'Suppression impossible : élément utilisé ailleurs.';

  // Photos
  static const camera = 'Appareil photo';
  static const gallery = 'Galerie';
  static const addPhoto = 'Ajouter une photo';

  // Password reset
  static const newPassword = 'Nouveau mot de passe';
  static const passwordReset = 'Mot de passe réinitialisé';
  static const noAccountWithEmail = 'Aucun compte avec cet email.';
  static const currentPassword = 'Mot de passe actuel';
  static const wrongCurrentPassword = 'Mot de passe actuel incorrect.';
  static const passwordChanged = 'Mot de passe modifié';
}
