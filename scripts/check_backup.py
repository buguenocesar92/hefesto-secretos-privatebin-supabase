#!/usr/bin/env python3
"""Verificacion de integridad de un respaldo de hefesto-secretos.

Codigos de salida: 0 integro, 1 uso, 2 integridad o manifiesto invalido,
4 material sensible en claro dentro del respaldo.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import verify
from respaldo_contrato import ejecutar


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Uso: python3 scripts/check_backup.py /ruta/respaldo")
    verify(sys.argv[1])
    print("Manifiesto, checksums y ausencia de secretos en claro verificados.")
    print("Esto no demuestra recuperacion PostgreSQL ni autenticidad del respaldo.")
    return 0


if __name__ == "__main__":
    raise SystemExit(ejecutar(main))
