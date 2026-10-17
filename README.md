# Hefesto Secretos · PrivateBin 2.0.6 + Supabase
Servicio para entregar notas confidenciales y credenciales temporales a clientes, basado en PrivateBin. El navegador cifra el contenido antes de enviarlo; PostgreSQL conserva el contenido cifrado. La clave de lectura viaja en el fragmento `#` del enlace, que el navegador no envía en la solicitud HTTP normal.

## Incluido
Compose para Coolify; PrivateBin nativo con PostgreSQL; gateway Caddy con Basic Auth; conexión TLS verify-full; rol exclusivo; configurador .env; respaldo con manifiesto y restauración en base vacía; guía de entrega a clientes. Imágenes fijadas por digest. No contiene datos reales, contraseñas de clientes ni imágenes Docker descargadas.

Interfaz upstream en español con nombre Hefesto Secretos. Texto plano, 100 KiB máximos por nota, sin adjuntos ni comentarios; expiraciones de 5 minutos, 10 minutos, 1 hora o 1 día. Se preselecciona quemar tras lectura; el usuario puede desmarcarlo. La contraseña adicional está disponible, pero el kit no la obliga. Los destinatarios también necesitan la credencial compartida de Basic Auth.

## Preparación
Requisitos: Docker Engine con Compose v2, Python 3.11+, dominio HTTPS y proyecto Supabase **nuevo y exclusivo** con PostgreSQL 16 o 17. Como punto inicial de evaluación, 1 CPU y 512 MiB–1 GiB de RAM en el VPS; medir con la carga real. Supabase tiene su propio consumo y condiciones de plan.

1. Descomprimir y entrar en esta carpeta. Ejecutar `python3 scripts/configure.py`: crea `.env` con permiso 0600, genera una clave DB hexadecimal y rechaza sobrescribirlo.
2. Crear un proyecto Supabase exclusivo; no reutilizar el de KraftDo u otro sistema. Desactivar su Data API en la configuración del proyecto. Este kit usa PostgreSQL, no Supabase Auth, Storage ni la API REST. No se necesita service_role.
3. Ejecutar `sql/01-supabase-app.sql` como administrador en SQL Editor. No contiene contraseña ni borra tablas. Falla si public contiene tablas. Asignar al rol `privatebin_app` la clave de `.env` mediante `\password privatebin_app` desde psql administrativo: solicita la clave sin incluirla en el comando ni el historial. El script configura privilegios por defecto para futuras tablas.
4. Completar DB_HOST, DB_USER y PUBLIC_URL. Preferir conexión directa puerto 5432; si el VPS no dispone de IPv6, usar el pooler **Session** en 5432 y DB_USER=`privatebin_app.PROJECTREF`. No usar Transaction 6543 para inicialización, copias ni restauración. Guardar la CA real del proyecto en `certs/ca.crt`, legible por los contenedores. No desactivar verify-full.
5. Cambiar las dos confirmaciones SUPABASE_* a true solo después de completar esos pasos. Los scripts comprueban permisos, rol y tablas, pero no pueden demostrar que pulsaste la opción Data API en el panel.
6. Generar un hash bcrypt para el acceso:

```sh
docker run --rm -it caddy:2-alpine@sha256:d8542f48d34a9cf4e4c11a478865229840e87e4c96ea3f439101f31a5d35f75f caddy hash-password --algorithm bcrypt --bcrypt-cost 12
```

Pegar el hash en BASIC_AUTH_HASH conservando las comillas simples del ejemplo. El usuario admite 3–48 caracteres alfanuméricos, guion o guion bajo. Usar una contraseña larga diferente de la DB. Los secretos solo se guardan en `.env` y en la configuración del despliegue; Docker y sus administradores pueden leer el entorno. No ejecutar `docker compose config` sin `--quiet` en logs públicos.

## Prueba privada antes de publicar

```sh
docker compose -f compose.yaml -f compose.bootstrap.yaml config --quiet
docker compose -f compose.yaml -f compose.bootstrap.yaml up -d
```

Abrir un túnel `ssh -L 8110:127.0.0.1:8110 usuario@servidor` y visitar `http://localhost:8110/`. Web Crypto funciona en localhost; no sustituirlo por una IP HTTP pública. El override solo admite esa URL local. Introducir Basic Auth y probar con `DEMO — sin datos reales` siguiendo `docs/ACEPTACION.md`. No se crean notas de prueba automáticamente.

## Coolify
Importar la carpeta completa desde repositorio privado como recurso Docker Compose. Usar solo `compose.yaml`; los montajes relativos `ops/` y `certs/` deben existir en el checkout o configurarse como archivos persistentes del recurso. La CA no es una clave secreta, pero tiene que proceder del proyecto correcto. Conservar permisos de lectura para el proceso no root de PrivateBin.

Introducir variables en el recurso; en el formulario Coolify el bcrypt se pega literal, sin las comillas envolventes de `.env`. Asignar un dominio HTTPS **solo a gateway, puerto 8080**. No publicar app, preflight ni dbtools ni añadir puertos del host. TLS termina en Coolify. Usar dominio raíz, sin subruta y con barra final en PUBLIC_URL.

Para cambiar desde la prueba local, detener el stack con ambos archivos y recrearlo usando solo compose.yaml, para eliminar el puerto local y LOCAL_PREVIEW. No reutilizar notas reales entre dominios. Una comprobación anónima del gateway devuelve 401: no configurar un healthcheck de Coolify que espere 200 sin credenciales. Verificar acceso autenticado mediante una prueba privada.

## Persistencia y seguridad práctica
Desde PrivateBin 1.4, el backend Database conserva también estado de servidor y limitadores en DB; en este kit no hay volumen persistente de documentos. `/srv/data` es temporal y el respaldo útil es PostgreSQL. No se modifica el motor criptográfico upstream. Se conserva CSP nativa y no se añaden analítica, acortadores ni JavaScript de terceros.

El cifrado depende del navegador y del JavaScript que sirve la instancia: un servidor comprometido puede entregar código malicioso. Quien obtiene el enlace completo y los accesos necesarios puede leer el contenido. No enviar contraseña adicional y enlace por el mismo canal. Escáneres de enlaces con JavaScript podrían consumir una nota de una lectura: probar el canal de entrega antes de usarlo con clientes.

Basic Auth es una barrera compartida, sin cuentas individuales, roles, MFA o cierre de sesión fiable. Para separar clientes, desplegar una instancia y un proyecto DB por cliente, o definir otra capa de identidad antes de ofrecer un portal multiusuario. La limitación nativa es conservadora: sin confiar en cabeceras IP, las creaciones a través del gateway comparten un límite de 10 segundos. No representa cuotas comerciales individuales.

La caducidad bloquea la lectura al vencer; la purga física es gradual y se activa con nuevas creaciones. Quemar o caducar no borra copias en respaldos, snapshots, dispositivos ni mensajes. Restaurar una copia puede devolver notas quemadas después de ella. Ver `docs/RESPALDO.md`.

## Traspaso y monetización
Ofrecer como complemento de soporte, onboarding y entrega segura de accesos. Se pueden adjuntar instrucciones o el enlace al proyecto/ticket de Odoo; no se incluye un conector automático ni se almacena el texto del secreto en Odoo. Para contraseñas permanentes usar la bóveda ya preparada para Hefesto. Ver `docs/ENTREGA.md`.

Kit preparado y revisado localmente, sin despliegue ejecutado. Revisar `docs/VALIDACION.md` y completar aceptación en un servidor de prueba antes de usarlo con clientes.
