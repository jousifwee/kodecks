# Frontend-Plan (Angular)

## Struktur
- Monorepo mit `@nrwl/nx` oder nativem Angular Workspace (`--create-application false`).
- Projekte:
  - `apps/patient-app` (PWA, mobile-first, vereinfachte UI).
  - `apps/portal` (Desktop-orientiertes Webportal für Angehörige & Pflege).
  - `libs/core` (Modelle, Auth-Service, Guards, Interceptors).
  - `libs/ui` (Design System, Angular Material/Theming, Barrierefreiheit).
  - `libs/api` (Generated Services via `openapi-typescript-codegen` oder manuell mit `HttpClient`).

## Authentifizierung
- Nutzung von `keycloak-angular` Paket.
- Silent Refresh via IFrame / Refresh Tokens.
- Rollenbasierte Guards (`RoleGuardService`), Zuweisung über Keycloak-Rollen.

## Hauptmodule
- **Patient-App:**
  - Dashboard mit Tagesplan (Timeline + Fortschrittsanzeige).
  - Chat-Komponente (Konversationen, Sprachnachricht-Upload via MediaRecorder).
  - Erinnerungsübersicht (Push & lokale Notifications).
- **Portal:**
  - Care Plan Editor (CRUD auf `daily_tasks`).
  - Task-Monitoring (Filter nach Status, Eskalationsindikatoren).
  - Messaging-Hub (Threaded View, Broadcast-Funktion).
  - Pflegebericht-Upload.

## Technik-Stack
- Angular 17+, Standalone Components, Signals für State.
- UI-Toolkit: Angular Material + Custom Theme mit großen Buttons, hoher Kontrast.
- Formulare mit `@ngneat/reactive-forms` oder Angular Reactive Forms.
- Internationale Darstellung (i18n) mit Transloco oder Angular i18n.
- PWA: Service Worker, Offline-Cache der letzten Aufgaben, IndexedDB (via `@ngx-pwa/local-storage`).

## Testing & Qualität
- Linting mit ESLint, Formatierung Prettier.
- Unit Tests (Jest), E2E (Cypress).
- Storybook für UI-Komponenten.

## Barrierefreiheit
- Große Schriftarten, kontrastreiche Farbpalette.
- Sprachunterstützung (Web Speech API) als Stretch Goal.
- Schritt-für-Schritt-Assistenten, einfache Navigation.

