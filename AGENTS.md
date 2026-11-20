# Repository Guidelines

## Project Structure & Module Organization
- `config/` holds PostgREST configuration; update `postgrest.conf` when schemas change.
- `db/` contains `schema.sql`, the canonical source of database structure and seed data.
- `docs/` captures architectural decisions; sync major changes with `docs/architecture.md`.
- `keycloak/` stores realm exports; treat `realm-export.json` as read-only unless you re-export.
- `docker-compose.yml` orchestrates the local stack (Postgres, PostgREST, Keycloak); keep service names stable for automation scripts.

## Build, Test, and Development Commands
- `cp .env.example .env` seeds environment variables; update secrets locally only.
- `docker compose up -d` launches the full stack; wait for health checks before testing APIs.
- `docker compose logs -f postgrest` tails API logs for request debugging.
- `docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -f /docker-entrypoint-initdb.d/01-schema.sql` reloads the schema inside the container when iterating on SQL.
- `docker compose down -v` resets containers and volumes; use sparingly to avoid data loss.

## Coding Style & Naming Conventions
- SQL: uppercase keywords (`SELECT`, `CREATE`), snake_case identifiers, and comment complex views with `--` annotations.
- JSON/YAML config: two-space indentation, quote strings containing special characters, keep property order stable to minimize diffs.
- Documentation: use concise English section headings; cross-link files with relative paths.

## Testing Guidelines
- Validate schema changes by running `docker compose exec postgres psql -c '\d'` to inspect tables after reloads.
- Exercise API endpoints with curl or Postman targeting `http://localhost:3000`; include JWTs from Keycloak when testing RLS.
- Before pushing, ensure migrations are idempotent by re-running the stack from a clean volume (`docker compose down -v && docker compose up -d`).
- Record manual test notes in `docs/testing.md` if new flows require sign-off.

## Commit & Pull Request Guidelines
- Follow Conventional Commits (`feat:`, `fix:`, `chore:`) as seen in `chore: scaffold demenzhilfe platform architecture`.
- Present tense, 50-character subject line, optional detail in the body separated by a blank line.
- Pull requests should link relevant issues, describe schema changes, and attach API screenshots or curl traces when altering endpoints.
- Request review from data and IAM maintainers when touching `db/` or `keycloak/` assets.

## Security & Configuration Tips
- Never commit populated `.env` files or local realm backups; add secrets via the deployment vault instead.
- Rotate JWT secrets and database passwords by updating `.env` and reissuing containers; confirm Keycloak imports succeed after each rotation.
