# Architekturüberblick: Demenzhilfe-Plattform

## Vision
Eine ganzheitliche Plattform, die Demenzpatient:innen im Alltag unterstützt, Angehörige einbindet und Pflegedienste miteinander vernetzt. Die Lösung besteht aus einem Postgres-Datenbank-Backend, PostgREST als API-Layer, einem Angular-Frontend (Web + mobile-ready via PWA) sowie einem zentralen Identity- und Access-Management mit Keycloak.

## Kernanforderungen
- **Multi-Channel-Kommunikation:** Text-, Bild- und Sprachnachrichten zwischen Patient:in, Angehörigen und Pflegedienst.
- **Tagesstruktur:** Aufgabenlisten und Routinen, die von Patient:innen abgehakt werden können, inkl. Erinnerungen.
- **Rollenbasierter Zugriff:** Unterschiedliche UI-Flows und Berechtigungen für Patient:innen, Angehörige und Pflegekräfte.
- **Offline-Fähigkeit (optional):** Mobile Nutzung auch bei schlechter Konnektivität, mit späterer Synchronisation.
- **Sicherheit & Datenschutz:** DSGVO-konforme Speicherung, Verschlüsselung, Audit-Logging.

## Systemkomponenten
```
┌────────────────────────────────────────────────────────────────┐
│                           Keycloak                             │
│              (Identity & Access Management)                    │
└────────────────────────────────────────────────────────────────┘
                  ▲                       ▲
                  │ OpenID Connect / OAuth2│
                  │                       │
┌──────────────────────────┐    ┌──────────────────────────────┐
│ Angular Web-App (PWA)    │    │ Angehörige/Pflege-Webportal  │
│  - Patient:innen UI      │    │  - Admin & Monitoring        │
│  - Aufgaben + Chat        │    │  - Aufgabenverwaltung        │
└──────────────────────────┘    └──────────────────────────────┘
                  ▲                       ▲
                  └───────────────┬───────┘
                                  │ HTTPS (JWT)
                         ┌────────▼─────────┐
                         │   PostgREST API  │
                         │  (RESTful Layer) │
                         └────────▲─────────┘
                                  │ SQL / RPC
                         ┌────────▼─────────┐
                         │   PostgreSQL      │
                         │  (Datenmodell)    │
                         └───────────────────┘
```

## Datenmodell (Auszug)
| Tabelle | Zweck | wichtige Spalten |
|---------|-------|------------------|
| `app.users` | zentrale Benutzer*innen | `id`, `external_id` (Keycloak UUID), `role`, `profile` JSONB |
| `app.patients` | Patient:innen-spezifische Infos | `user_id`, `care_plan`, `medical_notes` |
| `app.caregiver_assignments` | Zuordnung Angehörige/Pflegende ↔ Patient:in | `patient_id`, `contact_id`, `relationship`, `permissions` |
| `app.daily_tasks` | Aufgaben-Vorlagen | `patient_id`, `title`, `description`, `schedule`, `reminder_settings` |
| `app.task_instances` | Konkrete Tagesaufgaben | `task_id`, `date`, `status`, `completed_at`, `completed_by` |
| `app.messages` | Kommunikationshistorie | `conversation_id`, `sender_id`, `recipient_id`, `body`, `attachments`, `created_at` |
| `app.conversations` | Chat-Kanäle | `patient_id`, `type`, `participants`, `last_message_at` |
| `audit.events` | Nachvollziehbarkeit | `event_type`, `actor_id`, `payload`, `recorded_at` |

## Authentifizierung & Autorisierung
- **Keycloak** verwaltet Realm, Clients (Web, Mobile, PostgREST), Rollen und Gruppen.
- PostgREST erhält ein „Service-Account“-Token, validiert Endbenutzer*innen-JWTs via `jwt-secret` bzw. JWKS.
- RLS (Row-Level Security) in Postgres erzwingt autorisierte Datenzugriffe.
- Beispielrollen: `patient`, `relative`, `caregiver`, `coordinator`, `admin`.

## API-Strategie
- PostgREST stellt CRUD-Endpoints auf Tabellen/Views bereit.
- Für komplexere Abläufe (z. B. Check-in einer Tagesroutine, Broadcast-Nachrichten) werden SQL-Funktionen als RPC-Endpunkte veröffentlicht.
- Versionierung über Namespaces (`app`, `integration`, `audit`).

## Frontend-Architektur
- **Angular Workspace** mit getrennten Projekten für Patient:innen-App (PWA) und Angehörigen/Pflege-Webportal.
- Shared Library (`libs/core`, `libs/ui`, `libs/api`) für Models, Services, UI-Komponenten.
- State-Management via NgRx oder Akita für Offline-Sync.
- Responsive Design und Accessibility (WCAG 2.1 AA).
- Integration mit Keycloak über `keycloak-angular` und Silent Refresh.

## Kommunikationsfunktionen
- Channels (1:1, Gruppen) basierend auf `conversations`-Tabelle.
- Websocket-Gateway (optional) via `postgrest-ws` oder separater Node.js Signal-Komponente.
- Push-Benachrichtigungen über Web Push / Firebase Cloud Messaging.

## Deployment-Überlegungen
- Containerisierung via Docker Compose → später Kubernetes.
- Backups für Postgres, Monitoring (Prometheus/Grafana), Logging (ELK).
- Secrets-Management (z. B. HashiCorp Vault, Doppler).
- DSGVO: Hosting in EU, Verschlüsselung, Data Retention Policies.

## Nächste Schritte
1. Datenbankschema fertigstellen und RLS-Politiken definieren.
2. Keycloak Realm export/import definieren (Clients, Rollen, Gruppen, Mappers).
3. Angular Workspace initialisieren (`ng new demenzhilfe --create-application false`).
4. API-Mock (z. B. via PostgREST + Seed-Daten) für schnelle UI-Prototypen.
5. CI/CD-Pipeline (Linting, Tests, DB-Migrationen, Container Build).

## Offene Fragen
- Benötigte Integrationen (Kalender, Telemedizin, IoT?).
- Medien-Upload (Speicherort, Transkodierung, Zugriffskontrolle).
- Consent-Management für Angehörigen-Zugriffe.
- Barrierefreiheit für kognitive Einschränkungen (UX-Tests einplanen).

