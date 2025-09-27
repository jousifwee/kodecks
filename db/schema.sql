CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS audit;

-- Gemeinsame Trigger-Funktion für Updated-At-Spalten
CREATE OR REPLACE FUNCTION public.set_current_timestamp_on_update()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Benutzer:innen und Rollen
CREATE TABLE IF NOT EXISTS app.users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_id   UUID NOT NULL UNIQUE, -- Keycloak User-ID
    role          TEXT NOT NULL CHECK (role IN ('patient', 'relative', 'caregiver', 'coordinator', 'admin')),
    profile       JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON app.users
FOR EACH ROW
EXECUTE FUNCTION public.set_current_timestamp_on_update();

-- Patient:innen-spezifische Daten
CREATE TABLE IF NOT EXISTS app.patients (
    user_id          UUID PRIMARY KEY REFERENCES app.users(id) ON DELETE CASCADE,
    preferred_name   TEXT,
    care_plan        JSONB NOT NULL DEFAULT '{}'::jsonb,
    medical_notes    TEXT,
    emergency_info   JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_patients_updated_at
BEFORE UPDATE ON app.patients
FOR EACH ROW
EXECUTE FUNCTION public.set_current_timestamp_on_update();

-- Zugeordnete Kontakte (Angehörige, Pflegekräfte)
CREATE TABLE IF NOT EXISTS app.contacts (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
    patient_id    UUID NOT NULL REFERENCES app.patients(user_id) ON DELETE CASCADE,
    relationship  TEXT NOT NULL,
    permissions   JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Aufgaben-Templates
CREATE TABLE IF NOT EXISTS app.daily_tasks (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id       UUID NOT NULL REFERENCES app.patients(user_id) ON DELETE CASCADE,
    title            TEXT NOT NULL,
    description      TEXT,
    schedule         JSONB NOT NULL, -- z.B. {"type": "daily", "time": "08:00"}
    reminder_settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_daily_tasks_updated_at
BEFORE UPDATE ON app.daily_tasks
FOR EACH ROW
EXECUTE FUNCTION public.set_current_timestamp_on_update();

-- Tagesaufgaben-Instanzen
CREATE TABLE IF NOT EXISTS app.task_instances (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id        UUID NOT NULL REFERENCES app.daily_tasks(id) ON DELETE CASCADE,
    scheduled_for  DATE NOT NULL,
    status         TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'skipped')),
    completed_at   TIMESTAMPTZ,
    completed_by   UUID REFERENCES app.users(id),
    notes          TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Kommunikations-Kanäle
CREATE TABLE IF NOT EXISTS app.conversations (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id     UUID NOT NULL REFERENCES app.patients(user_id) ON DELETE CASCADE,
    type           TEXT NOT NULL CHECK (type IN ('patient_relatives', 'patient_caregivers', 'all_relatives', 'all_caregivers', 'custom')),
    participants   UUID[] NOT NULL,
    last_message_at TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES app.conversations(id) ON DELETE CASCADE,
    sender_id       UUID NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
    content         TEXT NOT NULL,
    attachments     JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Audit-Events
CREATE TABLE IF NOT EXISTS audit.events (
    id           BIGSERIAL PRIMARY KEY,
    event_type   TEXT NOT NULL,
    actor_id     UUID,
    payload      JSONB NOT NULL,
    recorded_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Row-Level Security (Platzhalter)
ALTER TABLE app.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.daily_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.task_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.messages ENABLE ROW LEVEL SECURITY;

-- Beispiel: Patient:innen sehen nur ihre eigenen Tasks
CREATE POLICY patient_task_instances_self_access
    ON app.task_instances
    FOR SELECT USING (
        current_setting('request.jwt.claim.role', true) = 'patient'
        AND EXISTS (
            SELECT 1
            FROM app.daily_tasks dt
            WHERE dt.id = task_id
              AND dt.patient_id = current_setting('request.jwt.claim.user_id', true)::uuid
        )
    );

