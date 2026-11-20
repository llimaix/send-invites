#!/bin/bash
# Vuelca el CSV exportado de la Google Sheet a invites.envios, EN EL SERVIDOR.
# Usa el psql del contenedor postgres del compose: no abre puertos ni instala nada.
#
# Uso (desde cualquier carpeta):
#   scripts/importar-sheet.sh /ruta/recordatorio.csv            # simulacro: muestra conteos y deshace
#   scripts/importar-sheet.sh /ruta/recordatorio.csv --aplicar  # guarda los cambios
#
# CSV esperado (Archivo > Descargar > CSV en Google Sheets), con o sin la columna Estado
# (el encabezado no distingue mayúsculas):
#   Nombre,Telefono,Invitados[,Estado]
#
# Qué hace, en una sola transacción:
#   - Inserta como 'pendiente' los teléfonos nuevos.
#   - Actualiza nombre e invitados de los que siguen 'pendiente'.
#   - Borra los 'pendiente' que ya no están en el CSV (p. ej. quien confirmó y quitaste de la hoja).
#   - No toca las filas ya enviadas (enviando, enviado, entregado, leido, fallido).
# Si hay una fila inválida o un teléfono repetido, no cambia nada.
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CSV="${1:-}"
MODO="${2:-}"

uso() { sed -n '5,7p' "$0" | sed 's/^# *//' >&2; exit 1; }
[ -n "$CSV" ] || uso
[ -f "$CSV" ] || { echo "No existe el archivo: $CSV" >&2; exit 1; }
case "$MODO" in
  "")        FIN="ROLLBACK" ;;
  --aplicar) FIN="COMMIT" ;;
  *)         uso ;;
esac

# Encabezado: sin BOM ni \r, sin distinguir mayúsculas. Define cuántas columnas carga COPY.
ENCABEZADO="$(head -n 1 "$CSV" | sed $'s/^\xEF\xBB\xBF//; s/\r$//' | tr '[:upper:]' '[:lower:]')"
case "$ENCABEZADO" in
  "nombre,telefono,invitados")        COLUMNAS="nombre, telefono, invitados";               NCOL=3 ;;
  "nombre,telefono,invitados,estado") COLUMNAS="nombre, telefono, invitados, estado_sheet"; NCOL=4 ;;
  *) echo "Encabezado inesperado: '$ENCABEZADO' (se espera Nombre,Telefono,Invitados[,Estado])" >&2; exit 1 ;;
esac

# Normaliza los datos ANTES de tocar Postgres, para no mandarle nunca un CSV a medias.
# Google Sheets omite las celdas vacías del final de cada fila: se completan con comas.
# El conteo de columnas respeta comillas ("D'León, Juan" es una sola columna).
DATOS="$(mktemp "${TMPDIR:-/tmp}/importar-sheet.XXXXXX")"
trap 'rm -f "$DATOS"' EXIT
awk -v n="$NCOL" '
  NR == 1 { next }
  {
    sub(/\r$/, "")
    if (!length($0)) next
    c = 1; q = 0
    for (i = 1; i <= length($0); i++) {
      ch = substr($0, i, 1)
      if (ch == "\"") q = !q
      else if (ch == "," && !q) c++
    }
    if (q) { printf "Fila %d de la hoja: comillas sin cerrar\n", NR > "/dev/stderr"; exit 3 }
    if (c > n) { printf "Fila %d de la hoja: %d columnas, se esperan %d\n", NR, c, n > "/dev/stderr"; exit 3 }
    while (c < n) { $0 = $0 ","; c++ }
    print
  }' "$CSV" > "$DATOS" || { echo "No se tocó la base de datos." >&2; exit 1; }

# Permite probar el script sin servidor (PSQL="cat" muestra lo que se enviaría).
PSQL="${PSQL:-docker compose --project-directory $DEPLOY_DIR exec -T postgres psql -X -q -U n8n -d n8n -v ON_ERROR_STOP=1}"

{
  cat <<SQL
SET client_encoding = 'UTF8';
BEGIN;
CREATE TEMP TABLE carga (
  fila serial, nombre text, telefono text, invitados text, estado_sheet text
) ON COMMIT DROP;
COPY carga ($COLUMNAS) FROM STDIN WITH (FORMAT csv);
SQL
  cat "$DATOS"
  printf '%s\n' '\.'
  cat <<'SQL'
UPDATE carga SET nombre    = btrim(nombre),
                 telefono  = regexp_replace(coalesce(telefono, ''), '[[:space:]-]', '', 'g'),
                 invitados = btrim(coalesce(invitados, ''));

DO $$
DECLARE
  n      int;
  malas  text;
  dobles text;
BEGIN
  SELECT count(*) INTO n FROM carga;
  IF n = 0 THEN
    RAISE EXCEPTION 'El CSV no tiene filas; no se toca la tabla';
  END IF;
  -- fila + 1 = número de fila en la hoja (la 1 es el encabezado), si no hay filas vacías.
  SELECT string_agg((fila + 1)::text, ', ' ORDER BY fila) INTO malas FROM carga
   WHERE telefono !~ '^\+[1-9][0-9]{7,14}$'
      OR coalesce(nombre, '') = ''
      OR (invitados <> '' AND invitados !~ '^[0-9]+$');
  IF malas IS NOT NULL THEN
    RAISE EXCEPTION 'Filas inválidas en la hoja: %', malas;
  END IF;
  SELECT string_agg((fila + 1)::text, ', ' ORDER BY fila) INTO dobles FROM carga
   WHERE telefono IN (SELECT telefono FROM carga GROUP BY telefono HAVING count(*) > 1);
  IF dobles IS NOT NULL THEN
    RAISE EXCEPTION 'Teléfonos repetidos en las filas de la hoja: %', dobles;
  END IF;
END $$;

WITH ins AS (
  INSERT INTO invites.envios (telefono, nombre, invitados)
  SELECT telefono, nombre, nullif(invitados, '')::int FROM carga
  ON CONFLICT (telefono) DO UPDATE
    SET nombre = EXCLUDED.nombre, invitados = EXCLUDED.invitados, actualizado_en = now()
    WHERE invites.envios.estado = 'pendiente'
  RETURNING (xmax = 0) AS nuevo
), del AS (
  DELETE FROM invites.envios e
  WHERE e.estado = 'pendiente'
    AND NOT EXISTS (SELECT 1 FROM carga c WHERE c.telefono = e.telefono)
  RETURNING 1
)
SELECT (SELECT count(*) FROM carga)              AS en_csv,
       (SELECT count(*) FROM ins WHERE nuevo)     AS insertados,
       (SELECT count(*) FROM ins WHERE NOT nuevo) AS actualizados,
       (SELECT count(*) FROM del)                AS eliminados;
SQL
  echo "$FIN;"
} | $PSQL

if [ "$FIN" = "ROLLBACK" ]; then
  echo "Simulacro: no se guardó nada. Repite con --aplicar para guardar." >&2
else
  echo "Cambios guardados." >&2
fi
