# Respaldo y recuperación
## Crear una copia
`python3 scripts/backup.py`

Pausa app, realiza pg_dump del esquema public, copia configuración, .env y CA, calcula SHA-256 y escribe status completed solo al terminar. Finalmente vuelve a arrancar app si estaba en marcha. El gateway puede mostrar 502 durante la pausa. No activar actualizaciones/despliegues simultáneos.

`python3 scripts/check_backup.py /ruta/respaldo` valida los archivos. Los checksums detectan corrupción, no prueban autenticidad ni la restauración de PostgreSQL. Una copia incompleta no tiene manifiesto válido.

El respaldo incluye credenciales DB, hash de Basic Auth y notas cifradas, metadatos y estado de limitación. Guardarlo cifrado fuera del VPS y con acceso restringido. No incluye enlaces completos/claves de lectura salvo que se hayan guardado indebidamente dentro del texto o de otros archivos. No incluye DNS, reglas de Coolify, imágenes Docker ni configuración del proyecto Supabase.

Para este servicio efímero puede ser preferible no respaldar notas y respaldar solo configuración: decidir la política con el cliente. Este script sí copia toda la DB. Definir retención corta, por ejemplo 24–72 horas según el compromiso acordado, y revisar también la retención de backups/PITR del proveedor. Expiración de notas y retención de backups son cosas distintas. No se programa ninguna tarea externa en esta entrega.

## Restaurar en un proyecto nuevo
1. Descomprimir este mismo kit en otra carpeta/servidor y preparar un proyecto Supabase nuevo mediante SQL y CA, Data API desactivada y rol propio. Generar .env nuevo con credenciales de destino. Mantener dominio y acceso de prueba privados; no sobrescribir la configuración de producción con la .env antigua.
2. Mantener app detenida. Guardar el respaldo original íntegro en una carpeta local confiable y validar con check_backup.py.
3. Ejecutar:
`python3 scripts/restore_db.py /ruta/respaldo --accept-note-resurrection`
4. El script verifica producto/versión/hash, app detenida, permisos y public vacío. No usa DROP ni sobrescribe tablas. Restaura sin owner/ACL del origen y en una transacción; conserva el esquema public que ya existe en Supabase. Las tablas quedan bajo el rol de destino, con sus privilegios por defecto.
5. Arrancar primero con el override bootstrap y realizar aceptación con una nota ficticia. No enviar enlaces recuperados a clientes hasta revisar qué contenidos podrían haberse reactivado. Una nota quemada después de la copia puede reaparecer si aún no caducó. Las notas vencidas siguen sujetas a su fecha de expiración.
6. Conservar el dominio original solo cuando corresponda: el script no cambia enlaces ya enviados. No hay archivos adjuntos o volumen de documentos que restaurar en este kit.

No hacer el ensayo contra el mismo proyecto de producción. .env de destino y CA deben apuntar al proyecto nuevo; comparar explícitamente DB_HOST antes de ejecutar.
