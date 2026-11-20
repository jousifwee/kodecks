# Angular UX Program Plan

## Überblick
- Ziel: Drei eigenständige, aber integrierbare Angular-SPAs für Patient:innen, Angehörige sowie Pflegedienste.
- Backend: PostgREST-API aus `docker-compose.yml`, abgesichert mit Keycloak.
- Gemeinsame Basistechniken: Angular 17+, Standalone Components, Angular Material, NgRx Signals Store, NX Workspace für geteilte Libraries.
- Qualitätsziele: WCAG 2.1 AA, responsive Layouts ab 320px, Lighthouse Performance >80.
- Pflegedienst-App optional; Angehörigen-Tool übernimmt primäre Kommunikationsfunktionen.

## Gemeinsame Grundlagen (Sprint 0)
- `nx` Monorepo initialisieren (`apps/patient-ux`, `apps/family-ux`, `apps/care-ux`, `libs/shared-ui`, `libs/shared-data`).
- Keycloak Auth-Guards, Token-Refresh-Service und Rollen-basierter Routen-Resolver in `libs/shared-security`.
- API Layer (`libs/shared-data`) mit OpenAPI-Generator auf PostgREST-Schema, Caching via Query Signals.
- Design-System definieren: Typografie, Farben, Spacing, Komponenten (Button, Card, Snackbar) als Storybook-Katalog.
- CI-Pipeline: Lint (ESLint), Unit (Jest), e2e (Cypress Component Testing) und Qualitäts-Gates in GitHub Actions.

## Patienten UX (`apps/patient-ux`)
- Personas: Menschen mit Demenz, Betreuungspersonen; Fokus auf Einfachheit und Kontraste.
- Kernrouten: `login`, `dashboard`, `medication`, `appointments`, `care-team`.
- Module: Medikamenten-Plan mit Erinnerungen, Tagesstruktur-Kalender (Drag & Drop), Symptom-Logging mit Charts.
- Integrationen: Push-Notifications via Web Push/APNS Proxy, Export nach PDF (Therapieplan).
- Sicherheit: Rollen `patient`, Multi-Faktor optional, Dateneinsicht ausschließlich eigene Daten.
- Milestones: Sprint 1 Auth & Dashboard, Sprint 2 Medikation, Sprint 3 Kalender, Sprint 4 Integrationen & Accessibility Audit.

## Angehörigen UX (`apps/family-ux`)
- Personas: Familienmitglieder mit Freigabe; Fokus Koordination & Einblick.
- Kernrouten: `login`, `care-overview`, `tasks`, `communication`, `resources`.
- Funktionen: Echtzeit-Aufgabenboard (SignalR/WebSocket), Freigabenverwaltung, Chat & Audio-Notizen mit Patient:innen, Wissensbibliothek mit Suchfunktion.
- Integrationen: Mitlesen der Patient:innen-Freigaben (RLS), Video-Sprechstunden-Link (extern), Benachrichtigungen via E-Mail, optionaler Übergabekanal zum Pflegedienst.
- Sicherheit: Rollen `family_viewer`, `family_admin`; Audit-Log Ansicht.
- Milestones: Sprint 1 Freigaben & Navigation, Sprint 2 Aufgabenboard, Sprint 3 Kommunikation, Sprint 4 Wissensbibliothek & e2e.

## Pflegedienst UX (`apps/care-ux`)
- Personas: Professionelle Pflegekräfte, Verwaltungsleitende (optional im Rollout).
- Kernrouten: `login`, `case-management`, `communication`, `reporting`, `staffing`.
- Rollout: Aktivierung nur bei angebundenem Pflegedienst; Angehörigen-App bleibt primärer Kommunikationskanal.
- Funktionen: Fallakten mit Verlaufsdokumentation, Pflegekommunikation via In-App-Chat & Telefonnotizen (Sync mit Angehörigen-Chat), KPI-Dashboards (D3/ngx-charts).
- Integrationen: Chat-Service (WebSocket) mit Archivierung & Channel-Sharing, Telefonie-Integrationsschnittstelle (SIP/VoIP Logs), Schnittstelle zu Abrechnung (REST webhook).
- Sicherheit: Rollen `care_nurse`, `care_manager`; fein granulare Berechtigungen auf Patienten-Cluster.
- Milestones: Sprint 1 Fallakten & Auth, Sprint 2 Kommunikationskanäle, Sprint 3 Reporting, Sprint 4 Integrationen & Performance Tuning.

## Abstimmung & Governance
- Wöchentlicher UX-Sync, zweiwöchentliche Architektur-Reviews; Entscheidungen in `docs/architecture.md` dokumentieren.
- Testing-Matrix je App: Unit (90% line coverage), e2e kritische Flows (Login, CRUD), manuelle Pflege-Ergonomie-Tests.
- Release cadence: Monatliche Minor-Releases, Hotfix-Channel für kritische Bugs.
- Rollout: Feature-Toggles per AppConfig, abgestufte Deployments (internal → pilot → public).

## Risiken & Gegenmaßnahmen
- Komplexe RLS-Regeln: frühzeitige DB-Schema-Validierung (`db/schema.sql`), automatisierte API-Contract-Tests.
- Kommunikation bei hohen Fallzahlen: WebSocket-Backpressure, revisionssichere Archivierung, Lighthouse Monitoring.
- Change Management für Pflegekräfte: In-App Tutorials, Feedback-Widget, Schulungsvideos in Angehörigen- und Pflege-App.
- Datenschutz: DPIA erstellen, Log-Retention begrenzen, regelmäßige Pen-Tests.
