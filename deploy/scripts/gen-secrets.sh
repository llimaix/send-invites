#!/bin/bash
# Genera deploy/.env EN EL SERVIDOR con secretos aleatorios.
# - No sobrescribe un .env existente.
# - Pide correo ACME, usuario y contraseña de la auth básica (la contraseña no se guarda,
#   solo su hash bcrypt).
# - Requiere: openssl y docker (para `caddy hash-password` con la misma imagen del compose).
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$DEPLOY_DIR/.env"
CADDY_IMAGE="caddy:2.11.9-alpine"

if [ -e "$ENV_FILE" ]; then
  echo "Ya existe $ENV_FILE; no lo sobrescribo. Bórralo a mano si de verdad quieres regenerarlo." >&2
  exit 1
fi

command -v openssl >/dev/null || { echo "Falta openssl" >&2; exit 1; }
command -v docker  >/dev/null || { echo "Falta docker"  >&2; exit 1; }

hex() { openssl rand -hex "$1"; }

read -r -p "Dominio [isdomana.com]: " DOMAIN
DOMAIN="${DOMAIN:-isdomana.com}"
read -r -p "Correo para Let's Encrypt: " ACME_EMAIL
read -r -p "ADMIN_CIDR [0.0.0.0/0]: " ADMIN_CIDR
ADMIN_CIDR="${ADMIN_CIDR:-0.0.0.0/0}"
read -r -p "Usuario auth básica [admin]: " BASIC_AUTH_USER
BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
read -r -s -p "Contraseña auth básica (mín. 16 caracteres): " BA_PASS; echo
read -r -s -p "Repite la contraseña: " BA_PASS2; echo
[ "$BA_PASS" = "$BA_PASS2" ] || { echo "No coinciden" >&2; exit 1; }
[ "${#BA_PASS}" -ge 16 ] || { echo "Debe tener al menos 16 caracteres" >&2; exit 1; }

BASIC_AUTH_HASH="$(docker run --rm -e BA_PASS="$BA_PASS" "$CADDY_IMAGE" \
  sh -c 'caddy hash-password --plaintext "$BA_PASS"')"
unset BA_PASS BA_PASS2

umask 077
cat > "$ENV_FILE" <<EOF
DOMAIN=$DOMAIN
ACME_EMAIL=$ACME_EMAIL
ADMIN_CIDR=$ADMIN_CIDR
BASIC_AUTH_USER=$BASIC_AUTH_USER
BASIC_AUTH_HASH='$BASIC_AUTH_HASH'

POSTGRES_SUPERUSER_PASSWORD=$(hex 24)
CHATWOOT_DB_PASSWORD=$(hex 24)
EVOLUTION_DB_PASSWORD=$(hex 24)
N8N_DB_PASSWORD=$(hex 24)
REDIS_PASSWORD=$(hex 24)

CHATWOOT_SECRET_KEY_BASE=$(hex 64)
EVOLUTION_API_KEY=$(hex 24)
N8N_ENCRYPTION_KEY=$(hex 32)
EOF
chmod 600 "$ENV_FILE"

echo "Listo: $ENV_FILE (permisos 600). No lo copies fuera del servidor ni lo subas a Git."
echo "Guarda EVOLUTION_API_KEY y N8N_ENCRYPTION_KEY en tu gestor de contraseñas."
