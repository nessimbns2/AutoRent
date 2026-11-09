# AutoRent 🚗 — Gestion de Location de Voitures

**AutoRent** est une application mobile Flutter moderne et **100 % hors-ligne** développée dans le cadre du cours de développement mobile à **ESPRIT**.

Elle digitalise une agence de location de voitures : flotte de véhicules, locataires (clients), entretiens, contrats de location avec contrôle de disponibilité en temps réel, et déclaration d'incidents / pannes.
Toutes les données sont enregistrées dans une **base SQLite** directement sur l'appareil : aucun serveur ni connexion Internet n'est nécessaire.

---

## 🔑 Identifiants de connexion (Comptes de démo)

L'application est initialisée automatiquement avec un jeu de données complet au premier lancement.
Sur l'écran de connexion, le bouton **« Utiliser le compte démo »** remplit les champs automatiquement.

| Rôle | Email | Mot de passe |
| :--- | :--- | :--- |
| **Agent de location** *(recommandé)* | `agent@autorent.tn` | `Agent123!` |
| **Agent secondaire** | `admin@autorent.tn` | `Admin123!` |

> ℹ️ *Tous les utilisateurs connectés ont un accès complet à l'ensemble des modules (architecture sans rôles ni admin).*

---

## 🚀 Lancement du projet

### Prérequis
- Flutter SDK (Dart ≥ 3.13)
- **Windows** : Visual Studio avec la charge de travail « Développement Desktop en C++ » (+ « Outils CMake C++ pour Windows ») et le **Mode développeur** de Windows activé
- **Android** : Android Studio avec un émulateur ou un téléphone connecté

### Dans VS Code
1. Ouvrir le dossier du projet.
2. Choisir l'appareil en bas à droite (ex. **Windows (windows-x64)**), ou la configuration **« AutoRent (Windows) »** dans l'onglet *Exécuter et déboguer*.
3. Appuyer sur **F5**.

### En ligne de commande

```bash
flutter pub get        # 1. Dépendances
flutter analyze        # 2. Analyse statique
flutter test           # 3. Tests unitaires & widgets
flutter run -d windows # 4. Lancement (ou -d <id> pour Android)
```

> Sur Windows, l'application s'ouvre dans une fenêtre au format téléphone ; si la fenêtre est agrandie, l'interface reste affichée dans un cadre de smartphone.

### Envoi automatique du contrat par e-mail

À la création d'une location, le contrat PDF est envoyé au client (s'il a une adresse e-mail) via Gmail SMTP. L'identifiant n'est pas dans le code : créez un fichier local `mail.env.json` (ignoré par git) avec un **mot de passe d'application** Gmail :

```json
{ "MAIL_USER": "votre.adresse@gmail.com", "MAIL_PASS": "mot-de-passe-d-application" }
```

Puis lancez l'application avec :

```bash
flutter run --dart-define-from-file=mail.env.json
```

Sans ce fichier, l'application fonctionne normalement et affiche « E-mail non configuré » à la création d'une location. (Pour un APK : `flutter build apk --dart-define-from-file=mail.env.json`.)

---

## 🎨 Interface (v2)

- **Design « Midnight & Sunset »** : bleu nuit + orange, police **Poppins**, cartes arrondies, ombres douces.
- **Mode sombre** : interrupteur dans l'onglet *Profil* ou bouton lune/soleil sur l'accueil (préférence mémorisée).
- **Barre de navigation flottante en bas** (comme une application mobile) avec 5 onglets :

| Onglet | Contenu |
| :--- | :--- |
| **Accueil** | Chiffre d'affaires du mois + graphique 6 mois, indicateurs, état de la flotte, départs/retours du jour, actions rapides, entretiens à venir |
| **Flotte** | Grille de véhicules avec photo, recherche, filtres par disponibilité (avec compteurs) et tri par prix |
| **Locations** | Contrats par statut (avec compteurs), recherche, « Mes / Toutes », barre de progression des locations en cours, badge **En retard** |
| **Suivi** | Entretiens **et** incidents regroupés (interrupteur), filtres par statut |
| **Profil** | Carte profil + statistiques, locataires, utilisateurs, base de données SQLite, mode sombre, déconnexion |

---

## 🔔 Notifications & règles métier

La cloche de l'accueil (avec compteur) ouvre le **centre de notifications**. Les alertes sont calculées à partir de la base SQLite et classées en **Urgent / Aujourd'hui / À venir** ; au démarrage, un message signale les alertes urgentes.

| Alerte | Règle |
| :--- | :--- |
| **Retour en retard** (urgent) | Location en cours dont la date de retour est dépassée, avec frais estimés |
| **Réservation non retirée** (urgent) | Réservation dont la date de départ est passée sans remise des clés |
| **Conflit entretien** (urgent) | Véhicule réservé (dans les 3 jours) alors qu'il est en atelier |
| **Entretien en retard** (urgent) | Entretien planifié dont la date est passée |
| **Incident en attente** | Incident non pris en charge (urgent après 2 jours) |
| **Retour aujourd'hui / demain** | Préparer l'état des lieux |
| **Départ aujourd'hui / réservation à préparer** | Départs du jour et des 2 prochains jours |
| **Entretien bientôt** | Entretien planifié dans les 3 jours |

Chaque alerte ouvre la fiche concernée ; elle peut être marquée comme lue (balayage ou « Tout lire »). Une alerte lue réapparaît si la situation change.

**Règles appliquées aux contrats** (`lib/core/constants/business_rules.dart`) :
- **Restitution en retard** : les jours de retard sont facturés au tarif journalier du contrat **majoré de 20 %** ; le détail est affiché avant validation et la date de retour est mise à jour.
- **Restitution anticipée** : le montant du contrat reste inchangé.
- **Prolongation** : nouvelle date de retour au même tarif journalier, refusée si le véhicule est déjà réservé sur la période.
- **Remise des clés** refusée tant que le véhicule est en entretien.

---

## 🚘 Données de démonstration

Au premier lancement (ou lors de la mise à jour vers la version 2 de la base), l'application installe une flotte de **6 véhicules avec photo** (`assets/vehicles/`) : Suzuki Swift, Škoda Fabia, Dacia Logan, Peugeot 208, Renault Clio et Audi Q3, ainsi que 8 locataires, 19 locations (terminées, en cours, en retard, réservées, annulée), 6 entretiens et 5 incidents.
Les dates sont calculées par rapport au jour d'installation pour que l'accueil et les notifications aient toujours du contenu.

> ⚠️ La migration vers la version 2 **remplace** les véhicules, locations, entretiens et incidents existants ; les utilisateurs et les locataires sont conservés.

---

## 📦 Fonctionnalités principales

1. **Authentification locale & Profil**
   - Inscription, connexion, réinitialisation de mot de passe hors-ligne, compte démo en un clic.
   - Modification du profil (nom, email, photo, mot de passe) et statistiques personnelles.
   - Gestion des comptes utilisateurs de l'agence.

2. **Tableau de bord**
   - Chiffre d'affaires du mois avec évolution vs mois précédent et mini-graphique sur 6 mois.
   - Indicateurs : locations en cours, réservations, véhicules libres, incidents ouverts.
   - État de la flotte (disponibles / louées / entretien / indisponibles) et taux d'occupation.
   - Alerte des locations en retard, départs et retours à traiter, entretiens des 14 prochains jours.

3. **Flotte de véhicules** (détail ci-dessous)
   - Fiche technique complète, filtres multicritères, archivage, documents administratifs avec échéances.
   - Fiche détaillée : galerie photo plein écran, tarif, nombre de locations, revenu généré, dernières locations.
   - Bouton **Louer maintenant**, planification d'entretien, historique, déclaration d'incident, fiche PDF.

4. **Contrats de location**
   - Choix du locataire (création rapide intégrée).
   - Période avec raccourcis (1 jour, 3 jours, 1 semaine, 2 semaines, 1 mois).
   - Sélection visuelle parmi les véhicules **réellement disponibles** (chevauchements et entretiens exclus).
   - Calcul automatique du montant ; frise de statut **Réservée ➔ En cours ➔ Terminée / Annulée**.
   - Détection des retards de restitution.

5. **Entretiens & révisions**
   - Types illustrés (Vidange, Pneus, Freins, Révision, Batterie, Autre), suivi par statut, historique par véhicule.

6. **Incidents & pannes**
   - Déclaration (Accident / Panne), lieu, description et photos de constat.
   - Rattachement automatique à la location en cours ; prise en charge puis résolution.

---

## 🚗 Module Véhicules (base v8)

**CRUD complet**
- **Fiche technique** : catégorie (citadine, compacte, berline, SUV, utilitaire, luxe), carburant, boîte de vitesses, places, année, couleur, kilométrage — affichée sur les cartes de la flotte (« SUV · Hybride · Auto · 5 pl. »).
- **Immatriculation tunisienne** validée au format `123 TUN 4567` et mise en forme pendant la saisie (taper `1234567` donne `123 TUN 4567`).
- **Photo de couverture** : l'étoile d'une photo la place en première position (carte, fiche, PDF).
- **Dupliquer** une fiche : copie des caractéristiques et du tarif, sans plaque, photos, kilométrage ni documents.
- **Archiver au lieu de supprimer** : un véhicule ayant un historique est retiré de la flotte (plus louable, absent des statistiques) tout en conservant ses locations, entretiens et incidents ; il peut être remis dans la flotte. L'archivage est refusé pendant une location en cours ou réservée.
- **Filtres multicritères** (Flotte ➔ ⚙) : catégorie, carburant, boîte, places minimum, fourchette de prix, tri (prix, année, kilométrage).

**Documents administratifs et échéances** (`vehicle_documents`)
- Assurance, visite technique, vignette et carte grise, avec numéro et date d'expiration (saisis dans le formulaire ou d'un toucher sur la fiche).
- Statut calculé : *Valide*, *Bientôt expiré* (≤ 30 jours), *Expiré*, *Non renseigné* ; badge « Docs » sur les cartes concernées.
- **Règle métier** : un véhicule dont l'**assurance** ou la **visite technique** est expirée — ou expire avant la fin de la location — **ne peut pas être loué** : il n'est plus proposé, et la création, la remise des clés et la prolongation sont refusées avec un message explicite. Son état devient « Docs expirés ».
- **Notifications** : document expiré (urgent), expirant dans 7 jours (aujourd'hui), dans 30 jours (à venir).

**Exports**
- **Fiche véhicule PDF** (menu ⋯ de la fiche) : identité, photo, caractéristiques, documents et leur statut, activité, dernières locations et entretiens.
- **Export CSV de la flotte** (Flotte ➔ ⤓) : une ligne par véhicule, ouvrable dans Excel (séparateur `;`, virgule décimale, UTF-8 avec BOM).
- Les fichiers sont enregistrés dans **Téléchargements** sur ordinateur (bouton « Ouvrir ») ou dans le dossier de l'application sur téléphone (le PDF peut aussi être partagé).

---

## 🗄️ Base de données SQLite

- Fichier `autorent.db` créé automatiquement au premier lancement (`sqflite`, et `sqflite_common_ffi` sur Windows / Linux / macOS).
- Tables reliées par clés étrangères (`users`, `clients`, `vehicles`, `vehicle_photos`, `vehicle_documents`, `maintenances`, `rentals`, `incidents`, `incident_photos`…) — voir [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- Version actuelle du schéma : **8** (`DatabaseHelper.schemaVersion`) ; chaque migration est appliquée automatiquement à l'ouverture.
- Jeu de données de démonstration inséré à la création.
- *Profil ➔ Base de données SQLite* affiche le nombre d'enregistrements par table et l'emplacement du fichier.

---

## 🛠️ Choix technologiques & Architecture

- **100 % hors-ligne** : aucune dépendance réseau ni API distante.
- **Persistance** : SQLite (`sqflite`), session et préférences (`shared_preferences`), photos dans le répertoire de l'application (`path_provider`).
- **UI / UX** : Material Design 3 personnalisé (`lib/app/theme.dart`), kit de composants réutilisables (`lib/core/widgets/shared_widgets.dart`), thème clair / sombre, textes et calendriers en français.
- **Architecture par couches** : `features/` ➔ `repositories/` ➔ `models/` + `core/`.
- **Navigation** : Navigator 1.0 avec routes nommées, arguments typés et garde de session ; état géré avec `StatefulWidget`, `setState` et `FutureBuilder` (périmètre du cours).
