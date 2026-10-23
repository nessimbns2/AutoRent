# Diagrams to copy into docs/ARCHITECTURE.md

Adjust names only if the generated code differs.

## 1. Layers (offline, no server)

```mermaid
flowchart TD
    subgraph Device["Android / iOS device — everything runs and is stored here"]
        subgraph UI["Presentation — features/"]
            S[Screens & tabs<br/>StatefulWidget + FutureBuilder]
            W[core/widgets<br/>shared widgets]
        end
        subgraph DATA["Data access — repositories/"]
            R[UserRepository · ClientRepository · VehicleRepository<br/>MaintenanceRepository · RentalRepository · IncidentRepository]
        end
        subgraph STORE["Storage — core/"]
            DB[(SQLite via sqflite<br/>autorent.db)]
            SP[(shared_preferences<br/>session id)]
            FS[(App documents dir<br/>photos/)]
        end
        M[models/ — plain Dart + fromMap/toMap]
    end
    S --> R
    S --> W
    R --> DB
    S --> SP
    S --> FS
    R --> M
    S --> M
```

## 2. Entity-relationship model

```mermaid
erDiagram
    USERS {
        int id PK
        text nom
        text prenom
        text email UK
        text password_hash
        text created_at
    }
    CLIENTS {
        int id PK
        text nom
        text prenom
        text telephone
        text email
        text numero_permis
    }
    VEHICLES {
        int id PK
        text marque
        text modele
        text immatriculation UK
        real prix_par_jour
        int disponible "0 | 1"
    }
    VEHICLE_PHOTOS {
        int id PK
        int vehicle_id FK
        text file_name
    }
    MAINTENANCES {
        int id PK
        int vehicle_id FK
        text type
        text date
        text description
        text statut "planifie | en_cours | termine"
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
    }
    INCIDENT_PHOTOS {
        int id PK
        int incident_id FK
        text file_name
    }
    VEHICLES ||--o{ VEHICLE_PHOTOS : has
    VEHICLES ||--o{ MAINTENANCES : "history of"
    VEHICLES ||--o{ RENTALS : "rented in"
    VEHICLES ||--o{ INCIDENTS : "concerned by"
    CLIENTS  ||--o{ RENTALS : signs
    USERS    ||--o{ RENTALS : "created by"
    USERS    ||--o{ INCIDENTS : "reported by"
    RENTALS  ||--o{ INCIDENTS : "during"
    INCIDENTS ||--o{ INCIDENT_PHOTOS : has
```

## 3. Navigation graph

```mermaid
flowchart TD
    Splash["/ Splash"] -->|no session| Login["/login"]
    Splash -->|session| Home["/home — HomeShell"]
    Login -->|pushReplacementNamed| Home
    Login --> Register["/register"]
    Login --> Forgot["/forgot-password"]

    subgraph Shell["HomeShell: AppBar + Drawer + BottomNavigationBar"]
        T0["Tab 0 Accueil"]
        T1["Tab 1 Véhicules<br/>TabBar: Tous · Disponibles · Indisponibles"]
        T2["Tab 2 Locations<br/>TabBar: Réservées · En cours · Terminées · Annulées"]
        T3["Tab 3 Entretiens<br/>TabBar: Planifiés · En cours · Terminés"]
        T4["Tab 4 Incidents<br/>TabBar: En attente · En cours · Résolus"]
    end
    Home --- Shell

    Drawer["Drawer"] --> Profile["/profile"]
    Drawer --> Clients["/clients"]
    Drawer --> Users["/users"]
    Drawer -->|confirm + pushNamedAndRemoveUntil| Login

    T1 --> VD["/vehicles/detail"] --> VF["/vehicles/form"]
    VD -->|Louer ce véhicule| RF["/rentals/form"]
    VD -->|Historique d'entretien| MH["/vehicles/maintenance-history"]
    VD -->|Planifier un entretien| MF["/maintenances/form"]
    T2 --> RD["/rentals/detail"] --> RF
    RD -->|Déclarer un incident| IF["/incidents/form"]
    T3 --> MD["/maintenances/detail"] --> MF
    T4 --> ID["/incidents/detail"] --> IF
    Users --> UD["/users/detail"] --> UF["/users/form"]
    Clients --> CD["/clients/detail"] --> CF["/clients/form"]
```

## 4. Typical call flow (create a rental)

```mermaid
sequenceDiagram
    participant U as Utilisateur
    participant F as RentalFormScreen
    participant R as RentalRepository
    participant DB as SQLite
    U->>F: choose renter, vehicle, dates, tap Enregistrer
    F->>F: Form.validate()
    F->>R: hasOverlap(vehicleId, start, end)
    R->>DB: SELECT COUNT(*) …
    DB-->>R: 0
    F->>R: insert(rental with prix_total)
    R->>DB: INSERT INTO rentals
    DB-->>R: id
    F-->>U: Navigator.pop(context, true) → list reloads
```
