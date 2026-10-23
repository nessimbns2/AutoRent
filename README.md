# AutoRent 🚗 — Gestion de Location de Voitures

**AutoRent** est une application mobile Flutter moderne et 100% hors-ligne développée dans le cadre du cours de développement mobile à **ESPRIT**.

Elle permet la digitalisation complète d'une agence de location de voitures : gestion de la flotte de véhicules, gestion des locataires (clients), suivi des entretiens périodiques, contrats de location avec contrôle de disponibilité en temps réel, et déclaration d'incidents / pannes.

---

## 🔑 Identifiants de connexion (Comptes de démo)

L'application est initialisée automatiquement avec un jeu de données complet au premier lancement :

| Rôle | Email | Mot de passe |
| :--- | :--- | :--- |
| **Agent de location** *(recommandé)* | `agent@autorent.tn` | `Agent123!` |
| **Agent secondaire** | `admin@autorent.tn` | `Admin123!` |

> ℹ️ *Note : Tous les utilisateurs connectés ont un accès complet à l'ensemble des modules (architecture sans rôles ni admin).*

---

## 🚀 Lancement du projet

### Prérequis
- Flutter SDK (≥ 3.13)
- Android Studio ou Xcode avec émulateur / appareil physique connecté

### Commandes

```bash
# 1. Récupération des dépendances
flutter pub get

# 2. Vérification de l'analyse statique
flutter analyze

# 3. Exécution des tests unitaires & de fumée
flutter test

# 4. Lancement de l'application
flutter run
```

---

## 📦 Fonctionnalités principales

1. **Authentification locale & Profil :**
   - Inscription, connexion, réinitialisation de mot de passe hors-ligne.
   - Modification du profil personnel et photo d'avatar.
   - Gestion des comptes utilisateurs de l'agence.

2. **Tableau de bord (Accueil) :**
   - Indicateurs en temps réel (locations en cours, réservations, incidents à traiter, véhicules au parc).
   - Raccourcis d'actions rapides (nouvelle location, déclarer incident, planifier entretien).

3. **Flotte de Véhicules :**
   - Filtrage par statut (Tous, Disponibles, Indisponibles).
   - Fiche technique complète, galerie photo, calcul automatique d'état de disponibilité.
   - Planification d'entretien et historique lié.

4. **Contrats de Location :**
   - Sélection du locataire (avec création rapide intégrée).
   - Sélecteur de période avec filtrage dynamique des véhicules réellement disponibles (détection des chevauchements et entretiens).
   - Calcul automatique du montant total.
   - Workflow de statut : Réservée ➔ En cours ➔ Terminée / Annulée.

5. **Entretiens & Révisions :**
   - Suivi par statut (Planifiés, En cours, Terminés).
   - Types d'interventions prédéfinis (Vidange, Pneus, Freins, Révision, Batterie, Autre).
   - Historique chronologique complet par véhicule.

6. **Incidents & Pannes :**
   - Déclaration rapide avec type (Accident / Panne), lieu, description et photos de constat.
   - Rattachement automatique au contrat de location actif.
   - Suivi de la prise en charge et de la résolution.

---

## 🛠️ Choix technologiques & Architecture

- **100% Offline :** Aucune dépendance réseau ni API distante.
- **Persistance :**
  - Base relationnelle locale : `sqflite` (schéma SQLite complet avec clés étrangères et cascade).
  - Session locale : `shared_preferences`.
  - Photos : Stockage interne sécurisé via `path_provider`.
- **UI / UX :**
  - Material Design 3 avec palette de couleurs agence (Orange).
  - Architecture par couches : `features/` ➔ `repositories/` ➔ `models/` + `core/`.
  - Navigation Navigator 1.0 avec routes nommées, arguments typés et garde de session.
