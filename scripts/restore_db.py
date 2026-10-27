#!/usr/bin/env python3
"""Restaura el esquema public de PrivateBin en un proyecto nuevo y vacio.

Sin --confirmar CONFIRMAR_RESTAURACION no se escribe nada; con --dry-run se
simula. Exige --accept-note-resurrection porque restaurar puede recuperar notas
que el usuario ya habia quemado.
"""
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import DATABASE, SOFTWARE, VERSION, dc, verify
from respaldo_contrato import (RespaldoError, auditar, ejecutar, escribir_informe,
                               opciones_restore)

RAIZ = Path(__file__).resolve().parents[1]
os.chdir(RAIZ)
os.umask(0o077)


def main():
    if "--accept-note-resurrection" not in sys.argv[1:]:
        raise SystemExit("Uso: python3 scripts/restore_db.py /ruta/respaldo "
                         "--confirmar CONFIRMAR_RESTAURACION --accept-note-resurrection "
                         "(recupera notas quemadas despues del respaldo)")
    modo, origen = opciones_restore([a for a in sys.argv[1:]
                                     if a != "--accept-note-resurrection"])
    backup = verify(origen)
    dump = backup / "public.dump"
    if modo == "dry-run":
        print("Simulacion: el respaldo es integro y no se escribio nada.")
        print("Para restaurar de verdad: --confirmar CONFIRMAR_RESTAURACION")
        return 0
    if dc("ps", "--status", "running", "-q", "app", capture_output=True, text=True).stdout.strip():
        raise RespaldoError("Detener app en destino antes de restaurar", 5)
    dc("run", "--rm", "--no-deps", "-T", "preflight")
    count = dc("run", "--rm", "--no-deps", "-T", "--entrypoint", "psql", "dbtools", "-Atc",
               "SELECT count(*) FROM pg_tables WHERE schemaname='public'",
               capture_output=True, text=True).stdout.strip()
    if count != "0":
        raise RespaldoError("public no esta vacio; no se sobrescriben datos", 5)
    with dump.open("rb") as stream:
        toc = dc("run", "--rm", "--no-deps", "-T", "--entrypoint", "pg_restore", "dbtools",
                 "--list", stdin=stream, stdout=subprocess.PIPE).stdout.decode()
    lineas = [l for l in toc.splitlines()
              if not re.match(r"^\d+;\s+\d+\s+\d+\s+SCHEMA\s+-\s+public(?:\s|$)", l)]
    with tempfile.TemporaryDirectory(prefix="hefesto-secretos-restore-") as d:
        ruta = Path(d) / "restore.list"
        ruta.write_text("\n".join(lineas) + "\n")
        os.chmod(d, 0o755)
        os.chmod(ruta, 0o644)
        with dump.open("rb") as stream:
            dc("run", "--rm", "--no-deps", "-T", "-v", d + ":/restore:ro", "--entrypoint",
               "pg_restore", "dbtools", "--exit-on-error", "--single-transaction",
               "--no-owner", "--no-acl", "--use-list=/restore/restore.list",
               "--dbname=postgres", stdin=stream)
    escribir_informe(backup, software=SOFTWARE, version=VERSION, database=DATABASE,
                     modo="confirmado", resultado="bd_restaurada", destino=str(RAIZ))
    auditar(RAIZ, operacion="restore_db", kit=SOFTWARE, origen=str(backup), destino=str(RAIZ),
            resultado="bd_restaurada")
    print("BD restaurada en proyecto nuevo. Probar solo por tunel privado y con notas ficticias.")
    return 0


if __name__ == "__main__":
    raise SystemExit(ejecutar(main))
