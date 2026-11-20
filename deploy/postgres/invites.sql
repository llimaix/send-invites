-- Cola y estado de los recordatorios. La lista de entrada vive en Google Sheets;
-- aquí n8n garantiza que cada teléfono reciba un solo mensaje.
-- Aplicar como el usuario n8n (dueño de la base n8n), no como superusuario:
--   docker compose exec -T postgres psql -U n8n -d n8n -v ON_ERROR_STOP=1 < postgres/invites.sql
-- Idempotente. Revertir: DROP SCHEMA invites CASCADE;

CREATE SCHEMA IF NOT EXISTS invites;

CREATE TABLE IF NOT EXISTS invites.envios (
  telefono        text PRIMARY KEY CHECK (telefono ~ '^\+[1-9][0-9]{7,14}$'),  -- E.164
  nombre          text NOT NULL,
  invitados       integer,
  estado          text NOT NULL DEFAULT 'pendiente'
                  CHECK (estado IN ('pendiente','enviando','enviado','entregado','leido','fallido')),
  intentos        integer NOT NULL DEFAULT 0,
  chatwoot_conversation_id integer,
  chatwoot_message_id      integer,
  wa_message_id   text,                  -- id de WhatsApp, para cruzar los eventos de Evolution
  error           text,
  enviado_en      timestamptz,
  creado_en       timestamptz NOT NULL DEFAULT now(),
  actualizado_en  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS envios_estado_idx ON invites.envios (estado);
CREATE INDEX IF NOT EXISTS envios_wa_message_id_idx ON invites.envios (wa_message_id);
