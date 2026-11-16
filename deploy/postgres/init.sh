#!/bin/bash
# Se ejecuta UNA sola vez, cuando el volumen de Postgres está vacío.
# Crea una base y un usuario propio por aplicación, y deja instaladas las extensiones
# de Chatwoot para que su usuario no necesite ser superusuario.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
  -v cw_pass="$CHATWOOT_DB_PASSWORD" \
  -v evo_pass="$EVOLUTION_DB_PASSWORD" \
  -v n8n_pass="$N8N_DB_PASSWORD" <<'SQL'
CREATE ROLE chatwoot  LOGIN PASSWORD :'cw_pass';
CREATE ROLE evolution LOGIN PASSWORD :'evo_pass';
CREATE ROLE n8n       LOGIN PASSWORD :'n8n_pass';

CREATE DATABASE chatwoot  OWNER chatwoot;
CREATE DATABASE evolution OWNER evolution;
CREATE DATABASE n8n       OWNER n8n;

\connect chatwoot
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
SQL
