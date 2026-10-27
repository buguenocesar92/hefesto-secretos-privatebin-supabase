import hashlib
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from respaldo_contrato import ejecutar_check

ROOT = Path(__file__).resolve().parents[1]
PRODUCT = "hefesto-secretos"
SOFTWARE = "hefesto-secretos"
VERSION = "2.0.6"
DATABASE = "postgresql"
# Configuracion y material que viajan en el respaldo. El .env NO viaja: solo
# sus nombres y, si hay receptor age, el .env cifrado.
FILES = ["compose.yaml", "compose.bootstrap.yaml", "ops/conf.php", "ops/Caddyfile",
         "ops/gateway-start.sh", "ops/app-start.sh", "ops/validate.php",
         "ops/zz-hefesto.conf", "ops/preflight.sh", "ops/preflight.sql"]
# Material opcional: solo viaja si existe en el kit (el CA de Supabase lo
# instala el operador en certs/, y no siempre esta presente).
FILES_OPCIONAL = ["certs/ca.crt"]


def dc(*args, **kw):
    return subprocess.run(["docker", "compose", "--project-directory", str(ROOT),
                           "-f", str(ROOT / "compose.yaml"), *args], check=True, **kw)


def sha(path):
    with path.open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def verify(path):
    """Verifica manifiesto, checksums, cobertura y ausencia de secretos en claro."""
    ejecutar_check(str(path), SOFTWARE, VERSION, DATABASE)
    return Path(path).resolve()
