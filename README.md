# Demenzhilfe Plattform

Dieses Repository enthält die Ausgangsbasis für eine Demenzhilfe-Lösung mit PostgreSQL-Backend, PostgREST als API-Layer, Angular-Frontends und Keycloak für Authentifizierung.

## Projektstruktur
```
.
├── config/                  # Konfigurationsdateien (PostgREST)
├── db/                      # SQL-Schemata & Migrationen
├── docs/                    # Architektur- und Design-Dokumentation
├── keycloak/                # Realm-Export und IAM-Konfiguration
├── docker-compose.yml       # Entwicklungs-Stack
└── .env.example             # Beispiel-Umgebungsvariablen
```

## Schnellstart
1. `.env.example` kopieren und als `.env` anpassen.
2. Docker-Stack starten:
   ```bash
   docker compose up -d
   ```
3. PostgREST ist unter `http://localhost:3000`, Keycloak unter `http://localhost:8080` erreichbar.
4. Angular-Workspace separat initialisieren (z. B. in `frontend/`).

## Datenbank
- Schema-Definitionen befinden sich in [`db/schema.sql`](db/schema.sql).
- Row-Level-Security ist vorbereitet; weitere Policies müssen ergänzt werden.

## Authentifizierung
- Keycloak-Export in [`keycloak/realm-export.json`](keycloak/realm-export.json) enthält Realm, Rollen und Beispiel-Clients.
- PostgREST erwartet JWTs mit Claim `role` und `user_id`.

## Weitere Informationen
- Detaillierter Architekturüberblick in [`docs/architecture.md`](docs/architecture.md).

