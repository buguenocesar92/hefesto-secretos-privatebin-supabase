#!/usr/bin/env python3
"""Respaldo de hefesto-secretos (PrivateBin + PostgreSQL/Supabase).

El .env nunca se copia en claro: al respaldo solo van sus nombres (env.vars) y,
si hay receptor age, el .env cifrado (env.age). Ver docs/CONTRATO-RESPALDO.md.
"""
import datetime
import os
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import DATABASE, FILES, FILES_OPCIONAL, ROOT, SOFTWARE, VERSION, dc
from respaldo_contrato import (artefactos_presentes, escribir_manifiesto, ejecutar,
                               exportar_env, marcar_fallido)

os.umask(0o077)


def main():
    for name in FILES:
        if not (ROOT / name).is_file():
            raise SystemExit("Falta archivo " + name)
    carpeta = ROOT / "backups" / datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    carpeta.mkdir(parents=True, mode=0o700)
    running = bool(dc("ps", "--status", "running", "-q", "app", capture_output=True, text=True).stdout.strip())
    try:
        dc("stop", "app")
        with (carpeta / "public.dump").open("wb") as f:
            dc("run", "--rm", "--no-deps", "-T", "--entrypoint", "pg_dump", "dbtools",
               "--format=custom", "--schema=public", "--no-owner", "--no-acl", stdout=f)
        for name in FILES + FILES_OPCIONAL:
            if not (ROOT / name).is_file():
                continue
            destino = carpeta / name
            destino.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, destino)
        meta = exportar_env(ROOT, carpeta)
        escribir_manifiesto(carpeta, SOFTWARE, VERSION, DATABASE,
                            artefactos_presentes(carpeta), extra=meta)
    except Exception:
        marcar_fallido(carpeta, SOFTWARE, VERSION, DATABASE)
        raise
    finally:
        if running:
            dc("start", "app")
    print("Respaldo:", carpeta)
    print("El .env no viaja en claro: solo env.vars y, si hay receptor age, env.age.")
    print("Contiene notas cifradas: restaurar puede recuperar notas ya quemadas.")
    return 0


if __name__ == "__main__":
    raise SystemExit(ejecutar(main))
