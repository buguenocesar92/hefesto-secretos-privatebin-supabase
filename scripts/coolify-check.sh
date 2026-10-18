#!/usr/bin/env bash
# Verifica que los compose del kit cumplen el contrato de Coolify:
#   1. Nada que salte Traefik ni dé poder sobre el host en servicios sin profiles.
#   2. Nombres estables sin forzar a nivel raíz, redes ni volúmenes.
#   3. Para apps con Postgres compartido (supabase-pg), DB_NAME y DB_SSLMODE
#      llegan al render (en el DSN o en variables de entorno del servicio web).
#
# Salida:
#   - exit 0 y "OK" si el contrato se cumple.
#   - exit 1 con cada incumplimiento "<servicio|red|volumen|compose>: <motivo>"
#     si hay cualquier violación.
#
# Uso: bash scripts/coolify-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Composes a verificar. Formato: <base_dir>|<archivo>|<tipo_bd>
# tipo_bd ∈ {supabase-pg, supabase-rest, none}
COMPOSES=(
  "$REPO_ROOT|compose.yaml|supabase-pg"
)

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

ERRORS=()

fail() {
  ERRORS+=("$1")
  echo "$1" >&2
}

# Renderiza un compose y devuelve el JSON normalizado.
render_compose() {
  local base_dir="$1"
  local compose_file="$2"
  local env_file="$3"
  local out
  if ! out=$(docker compose --project-directory "$base_dir" -f "$compose_file" --env-file "$env_file" config --format json 2> "$TMPDIR/render.err"); then
    local err
    err=$(cat "$TMPDIR/render.err")
    fail "$compose_file: error al renderizar: $err"
    return 1
  fi
  printf '%s' "$out"
}

# Chequeos estructurales sobre el ARCHIVO compose (no el render, que autollena
# `name` y nombres de redes/volúmenes a partir del directorio del proyecto).
check_source() {
  local compose_file="$1"
  local out_file="$TMPDIR/source-$(basename "$compose_file").txt"
  python3 - "$compose_file" "$REPO_ROOT" > "$out_file" <<'PY' || true
import sys
import yaml

compose_file, repo_root = sys.argv[1], sys.argv[2]
with open(compose_file) as f:
    data = yaml.safe_load(f) or {}

label = compose_file

# Punto 2: name: a nivel raíz.
if 'name' in data:
    print(f"{label}: tiene 'name:' a nivel raiz (Coolify pone el nombre del proyecto)")

# Punto 1: campos prohibidos en servicios sin profiles.
for service, cfg in (data.get('services') or {}).items():
    profiles = cfg.get('profiles') or []
    if profiles:
        continue
    for field in ('ports', 'container_name', 'privileged', 'cap_add',
                  'devices', 'network_mode', 'pid', 'ipc'):
        if field in cfg:
            print(f"{service}: campo prohibido '{field}' (debe quedar detras de Traefik)")
    sec_opt = cfg.get('security_opt') or []
    if any('unconfined' in str(s) for s in sec_opt):
        print(f"{service}: security_opt contiene 'unconfined'")
    for vol in (cfg.get('volumes') or []):
        if isinstance(vol, str) and 'docker.sock' in vol:
            print(f"{service}: monta docker.sock")
            break
    for vol in (cfg.get('volumes') or []):
        if not isinstance(vol, str):
            continue
        src = vol.split(':', 1)[0]
        if src.startswith('/') and src != '/dev/null' and not src.startswith(repo_root):
            print(f"{service}: bind fuera del repositorio (no permitido en Coolify)")
            break

# Punto 2: redes sin name fijo.
for net, cfg in (data.get('networks') or {}).items():
    if isinstance(cfg, dict) and cfg.get('name'):
        print(f"red {net}: name fijo '{cfg['name']}' (Coolify pone el nombre del proyecto)")

# Punto 2: volúmenes sin name fijo.
for vol, cfg in (data.get('volumes') or {}).items():
    if isinstance(cfg, dict) and cfg.get('name'):
        print(f"volumen {vol}: name fijo '{cfg['name']}'")
PY
  local line
  while IFS= read -r line; do
    [ -n "$line" ] && fail "$line"
  done < "$out_file"
}

# Punto 3: comprobar DB_NAME y DB_SSLMODE en render para supabase-pg.
check_supabase_pg() {
  local render="$1"
  local label="$2"

  local has_dbname
  has_dbname=$(echo "$render" | jq -r '[.. | strings] | map(select(. == "mvp_prueba")) | length')
  if [ "$has_dbname" = "0" ]; then
    fail "$label: DB_NAME=mvp_prueba no aparece en el render (DSN o variables del servicio web)"
  fi

  local has_sslmode
  has_sslmode=$(echo "$render" | jq -r '
    [
      ..
      | objects
      | to_entries[]
      | select((.key | type == "string") and (.key | test("SSLMODE$")))
      | .value
    ]
    | map(select(. == "disable"))
    | length
  ')
  if [ "$has_sslmode" = "0" ]; then
    fail "$label: DB_SSLMODE=disable no aparece en el render"
  fi
}

main() {
  for entry in "${COMPOSES[@]}"; do
    IFS='|' read -r base_dir compose_file db_type <<< "$entry"

    local env_file="$TMPDIR/$(basename "$compose_file").env"
    cat > "$env_file" <<'EOF'
PUBLIC_URL=https://ejemplo.invalid/
DB_HOST=db.ejemplo.invalid
DB_USER=x1234
DB_PASSWORD=x12345678901234567890123456789012
SUPABASE_DEDICATED_CONFIRMED=true
SUPABASE_DATA_API_DISABLED=true
BASIC_AUTH_USER=x1234
BASIC_AUTH_HASH=x1234567890abcdef
EOF
    if [ "$db_type" = "supabase-pg" ]; then
      cat >> "$env_file" <<'EOF'
DB_SSLMODE=disable
DB_NAME=mvp_prueba
EOF
    fi

    echo "=== Verificando $compose_file (bd=$db_type) ==="

    check_source "$compose_file"

    local render
    if render=$(render_compose "$base_dir" "$compose_file" "$env_file"); then
      if [ "$db_type" = "supabase-pg" ]; then
        check_supabase_pg "$render" "$compose_file"
      fi
    fi
  done

  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "ERROR: ${#ERRORS[@]} incumplimiento(s) del contrato Coolify" >&2
    exit 1
  fi

  echo "OK: contrato Coolify cumplido"
}

main
