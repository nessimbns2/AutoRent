# Architecture de l'application AutoRent

AutoRent est une application Flutter autonome (100% hors-ligne) pour la gestion d'une agence de location de véhicules, conçue dans le cadre du cours de développement mobile à ESPRIT.

---

## 1. Vue d'ensemble & Principes directeurs

- **100% Hors-ligne / Aucune API serveur :** Toutes les données opérationnelles sont stockées en local sur le terminal (SQLite avec `sqflite`). Les préférences et identifiants de session sont conservés dans `shared_preferences`. Les images sont enregistrées dans le répertoire des documents de l'application (`path_provider`).
- **Périmètre du cours :** Utilisation stricte des composants fondamentaux de Flutter (`StatefulWidget`, `setState`, `FutureBuilder`, Navigator 1.0 avec routes nommées et arguments typés). Aucune bibliothèque d'état externe complexe (Provider, Riverpod, Bloc, etc.).
- **Authentification sans rôles :** Un seul profil d'utilisateur (« Agent de location »). Tout utilisateur connecté accède à la totalité des fonctionnalités de l'application sans distinction administrative ni restriction par rôles.

---

## 2. Diagramme des couches (Layers)

```mermaid
flowchart TD
    subgraph Device["Android / iOS device — tout s'exécute et est stocké localement"]
        subgraph UI["Présentation — features/"]
            S["Écrans & onglets<br/>StatefulWidget + FutureBuilder"]
            W["core/widgets<br/>Composants réutilisables"]
        end
        subgraph DATA["Accès aux données — repositories/"]
            R["UserRepository · ClientRepository · VehicleRepository<br/>MaintenanceRepository · RentalRepository · IncidentRepository"]
        end
        subgraph STORE["Stockage — core/"]
            DB[("SQLite via sqflite<br/>autorent.db")]
            SP[("shared_preferences<br/>id session")]
            FS[("Répertoire documents<br/>photos/")]
        end
        M["models/ — classes Dart pures + fromMap/toMap"]
    end
    S --> R
    S --> W
    R --> DB
    S --> SP
    S --> FS
    R --> M
    S --> M
```

---

## 3. Schéma Entité-Association (ERD)

```mermaid
erDiagram
    USERS {
        int id PK
        text nom
        text prenom
        text email UK
        text password_hash
        text photo_file
        text created_at
    }
    CLIENTS {
        int id PK
        text nom
        text prenom
        text telephone
        text email
        text numero_permis
        text created_at
    }
    VEHICLES {
        int id PK
        text marque
        text modele
        text immatriculation UK
        real prix_par_jour
        int disponible "0 | 1"
        text created_at
    }
    VEHICLE_PHOTOS {
        int id PK
        int vehicle_id FK
        text file_name
        int position
    }
    MAINTENANCES {
        int id PK
        int vehicle_id FK
        text type
        text date
        text description
        text statut "planifie | en_cours | termine"
        text created_at
    }
    RENTALS {
        int id PK
        int client_id FK
        int vehicle_id FK
        int user_id FK
        text date_debut
        text date_fin
        real prix_total
        text statut "reservee | en_cours | terminee | annulee"
        text created_at
    }
    INCIDENTS {
        int id PK
        int vehicle_id FK
        int rental_id FK "nullable"
        int reported_by_user_id FK
        text type "accident | panne"
        text date
        text lieu
        text description
        text statut "en_attente | en_cours | resolu"
        text created_at
    }
    INCIDENT_PHOTOS {
        int id PK
        int incident_id FK
        text file_name
        int position
    }
    VEHICLES ||--o{ VEHICLE_PHOTOS : has
    VEHICLES ||--o{ MAINTENANCES : "historique"
    VEHICLES ||--o{ RENTALS : "loué dans"
    VEHICLES ||--o{ INCIDENTS : "concerné par"
    CLIENTS  ||--o{ RENTALS : signe
    USERS    ||--o{ RENTALS : "créé par"
    USERS    ||--o{ INCIDENTS : "déclaré par"
    RENTALS  ||--o{ INCIDENTS : "pendant"
    INCIDENTS ||--o{ INCIDENT_PHOTOS : has
```

---

## 4. Graphe de Navigation

```mermaid
flowchart TD
    Splash["/ (Splash)"] -->|non connecté| Login["/login"]
    Splash -->|session active| Home["/home — HomeShell"]
    Login -->|connexion réussie| Home
    Login --> Register["/register"]
    Login --> Forgot["/forgot-password"]

    subgraph Shell["HomeShell : AppBar + AppDrawer + BottomNavigationBar"]
        T0["Onglet 0 : Accueil (Dashboard)"]
        T1["Onglet 1 : Véhicules (Tous · Disponibles · Indisponibles)"]
        T2["Onglet 2 : Locations (Réservées · En cours · Terminées · Annulées)"]
        T3["Onglet 3 : Entretiens (Planifiés · En cours · Terminés)"]
        T4["Onglet 4 : Incidents (En attente · En cours · Résolus)"]
    end
    Home --- Shell

    AppDrawer["AppDrawer"] --> Profile["/profile"]
    AppDrawer --> Clients["/clients"]
    AppDrawer --> Users["/users"]
    AppDrawer -->|Déconnexion| Login

    T1 --> VD["/vehicles/detail"] --> VF["/vehicles/form"]
    VD -->|Louer ce véhicule| RF["/rentals/form"]
    VD -->|Historique d'entretien| MH["/vehicles/maintenance-history"]
    VD -->|Planifier entretien| MF["/maintenances/form"]

    T2 --> RD["/rentals/detail"] --> RF
    RD -->|Déclarer un incident| IF["/incidents/form"]

    T3 --> MD["/maintenances/detail"] --> MF
    T4 --> ID["/incidents/detail"] --> IF

    Users --> UD["/users/detail"] --> UF["/users/form"]
    Clients --> CD["/clients/detail"] --> CF["/clients/form"]
```

---

## 5. Description des couches

### Présentation (`lib/features/`)
- Contient les écrans et onglets organisés par module métier (`auth`, `home`, `vehicles`, `rentals`, `maintenances`, `incidents`, `clients`, `users`, `profile`).
- Chaque écran est relié aux repositories, reçoit ses paramètres via son constructeur (déballés par `AppRouter`) et retourne un résultat booléen (`true` en cas de modification/suppression) pour rafraîchir la vue appelante.

### Couche d'accès aux données (`lib/repositories/`)
- Encapsule l'ensemble des requêtes SQL SQLite (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) et les transactions ACID.
- Valide les règles métier critiques (unicité des immatriculations/emails, chevauchement de dates pour les locations, vérification d'intégrité référentielle avant suppression).
- Lève des `AppException` avec des messages clairs en français en cas de conflit ou de violation de contrainte.

### Couche Modèles (`lib/models/`)
- Objets métiers immuables (`User`, `Client`, `Vehicle`, `Maintenance`, `Rental`, `Incident`) et leurs vues de jointure (`RentalView`, `MaintenanceView`, `IncidentView`).
- Gère la sérialisation bidirectionnelle : noms de colonnes SQL snake_case en français vers champs Dart camelCase en anglais.

### Services & Utilitaires transverses (`lib/core/`)
- `DatabaseHelper` : Singleton SQLite orchestrant les schémas DDL, clés étrangères et le jeu de données initial (seeding).
- `SessionManager` : Gestion de la persistance de la session locale via `SharedPreferences`.
- `PasswordHasher` : Hachage sécurisé des mots de passe en SHA-256 avec sel aléatoire.
- `ImageStorage` : Enregistrement et résolution locale des photos dans l'espace de stockage de l'appareil.
- `Strings` : Centralisation des chaînes de caractères de l'interface en français.
