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

# Composes a verificar. Formato: <base_dir>|<archivo_relativo>|<tipo_bd>
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

# Renderiza un compose y devuelve el JSON normalizado. Devuelve 1 si falla,
# pero NO llama a `fail` (eso lo hace el caller en el contexto principal
# para que el error no se pierda en el subshell de la sustitución de comando).
render_compose() {
  local base_dir="$1"
  local compose_file="$2"
  local env_file="$3"
  if ! docker compose --project-directory "$base_dir" -f "$compose_file" \
      --env-file "$env_file" config --format json \
      2> "$TMPDIR/render.err" > "$TMPDIR/render.json"; then
    return 1
  fi
  cat "$TMPDIR/render.json"
}

# Genera un .env temporal a partir de las ${VAR} que aparecen en el compose.
# Las de host/URL se inventan apuntando a un dominio inválido; el resto recibe
# un valor ficticio no secreto. Para supabase-pg se fuerzan DB_NAME=mvp_prueba
# y DB_SSLMODE=disable (los exige el punto 3 del contrato).
generate_env() {
  local compose_file="$1"
  local db_type="$2"
  local env_file="$3"
  local vars
  vars=$(grep -oE '\$\{[A-Z_][A-Z0-9_]*|\$[A-Z_][A-Z0-9_]*' "$compose_file" \
    | sed -E 's/^\$\{?//' \
    | sort -u) || vars=""
  : > "$env_file"
  local key
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    case "$key" in
      PUBLIC_URL|DB_HOST|STORAGE_HOST)
        echo "$key=https://ejemplo.invalid" >> "$env_file"
        ;;
      *)
        echo "$key=x1234567890" >> "$env_file"
        ;;
    esac
  done <<< "$vars"
  if [ "$db_type" = "supabase-pg" ]; then
    echo "DB_SSLMODE=disable" >> "$env_file"
    echo "DB_NAME=mvp_prueba" >> "$env_file"
  fi
  return 0
}

# Chequeos sobre el ARCHIVO compose (no el render, que autollena `name`).
# Cubre: name a nivel raíz y `name:` fijo en redes y volúmenes declarados.
check_source() {
  local compose_file="$1"
  local out_file="$TMPDIR/source-$(basename "$compose_file").txt"
  if ! python3 - "$compose_file" "$REPO_ROOT" > "$out_file" <<'PY'
import sys
import yaml

compose_file, _repo_root = sys.argv[1], sys.argv[2]
with open(compose_file) as f:
    data = yaml.safe_load(f) or {}

label = compose_file

# Punto 2: name: a nivel raíz.
if 'name' in data:
    print(f"{label}: tiene 'name:' a nivel raiz (Coolify pone el nombre del proyecto)")

# Punto 2: redes sin name fijo.
for net, cfg in (data.get('networks') or {}).items():
    if isinstance(cfg, dict) and cfg.get('name'):
        print(f"red {net}: name fijo '{cfg['name']}' (Coolify pone el nombre del proyecto)")

# Punto 2: volúmenes sin name fijo.
for vol, cfg in (data.get('volumes') or {}).items():
    if isinstance(cfg, dict) and cfg.get('name'):
        print(f"volumen {vol}: name fijo '{cfg['name']}'")
PY
  then
    fail "$compose_file: no se pudo analizar el compose"
    return 1
  fi
  local line
  while IFS= read -r line; do
    [ -n "$line" ] && fail "$line"
  done < "$out_file"
  return 0
}

# Chequeos sobre el RENDER (con jq) para los puntos 1 y 2 del contrato:
# campos prohibidos, security_opt=unconfined, binds fuera del repo o
# docker.sock. La normalización del render unifica la sintaxis corta y
# larga de volúmenes.
check_render() {
  local render="$1"
  local label="$2"

  local forbidden
  if ! forbidden=$(echo "$render" | jq -r '
    .services
    | to_entries[]
    | select((.value.profiles // []) | length == 0)
    | .key as $s
    | .value
    | to_entries[]
    | select(
        .key == "ports" or .key == "container_name" or .key == "privileged"
        or .key == "cap_add" or .key == "devices" or .key == "network_mode"
        or .key == "pid" or .key == "ipc"
      )
    | "\($s): campo prohibido [\(.key)] (debe quedar detras de Traefik)"
  '); then
    fail "$label: no se pudo analizar el render (campos prohibidos)"
    forbidden=""
  fi
  while IFS= read -r line; do
    [ -n "$line" ] && fail "$label: $line"
  done <<< "$forbidden"

  local unconfined
  if ! unconfined=$(echo "$render" | jq -r '
    .services
    | to_entries[]
    | select((.value.profiles // []) | length == 0)
    | .key as $s
    | (.value.security_opt // [])[]
    | select(test("unconfined"))
    | "\($s): security_opt contiene unconfined"
  '); then
    fail "$label: no se pudo analizar el render (security_opt)"
    unconfined=""
  fi
  while IFS= read -r line; do
    [ -n "$line" ] && fail "$label: $line"
  done <<< "$unconfined"

  local bad_binds
  if ! bad_binds=$(echo "$render" | jq -r --arg repo "$REPO_ROOT" '
    .services
    | to_entries[]
    | select((.value.profiles // []) | length == 0)
    | .key as $s
    | (.value.volumes // [])[]
    | select(type == "object" and .type == "bind")
    | . as $bind
    | select(
        (($bind.source | startswith($repo) | not) and ($bind.source != "/dev/null"))
        or ($bind.source | test("docker\\.sock"))
      )
    | "\($s): bind no permitido en \($bind.source)"
  '); then
    fail "$label: no se pudo analizar el render (binds)"
    bad_binds=""
  fi
  while IFS= read -r line; do
    [ -n "$line" ] && fail "$label: $line"
  done <<< "$bad_binds"
  return 0
}

# Punto 3: comprobar DB_NAME y DB_SSLMODE en render para supabase-pg.
check_supabase_pg() {
  local render="$1"
  local label="$2"

  local has_dbname
  has_dbname=$(echo "$render" | jq -r '
    [.. | objects | to_entries[] | .value | strings | select(. == "mvp_prueba")]
    | length
  ' 2>/dev/null || echo 0)
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
  ' 2>/dev/null || echo 0)
  if [ "$has_sslmode" = "0" ]; then
    fail "$label: DB_SSLMODE=disable no aparece en el render"
  fi
  return 0
}

main() {
  for entry in "${COMPOSES[@]}"; do
    IFS='|' read -r base_dir compose_rel db_type <<< "$entry"
    local compose_file="$base_dir/$compose_rel"

    local env_file="$TMPDIR/$(basename "$compose_file").env"
    generate_env "$compose_file" "$db_type" "$env_file"

    echo "=== Verificando $compose_file (bd=$db_type) ==="

    check_source "$compose_file"

    local render
    if render=$(render_compose "$base_dir" "$compose_file" "$env_file"); then
      check_render "$render" "$compose_file"
      if [ "$db_type" = "supabase-pg" ]; then
        check_supabase_pg "$render" "$compose_file"
      fi
    else
      local err
      err=$(cat "$TMPDIR/render.err" 2>/dev/null || true)
      fail "$compose_file: no renderiza: ${err:-comando fallo sin mensaje}"
    fi
  done

  if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "ERROR: ${#ERRORS[@]} incumplimiento(s) del contrato Coolify" >&2
    exit 1
  fi

  echo "OK: contrato Coolify cumplido"
}

main
