# Fuentes · consultadas 2026-10-16
- https://github.com/PrivateBin/PrivateBin/releases/tag/2.0.6
- https://github.com/PrivateBin/PrivateBin/blob/2.0.6/cfg/conf.sample.php
- https://github.com/PrivateBin/PrivateBin/blob/2.0.6/lib/Configuration.php
- https://github.com/PrivateBin/PrivateBin/blob/2.0.6/lib/Data/Database.php
- https://github.com/PrivateBin/docker-nginx-fpm-alpine
- https://github.com/PrivateBin/docker-nginx-fpm-alpine/blob/master/etc/php/php-fpm.d/zz-docker.conf
- https://hub.docker.com/r/privatebin/nginx-fpm-alpine/tags
- https://www.php.net/manual/en/function.parse-ini-file.php
- https://www.php.net/manual/en/ref.pdo-pgsql.connection.php
- https://supabase.com/docs/guides/database/connecting-to-postgres
- https://supabase.com/docs/guides/platform/ssl-enforcement
- https://caddyserver.com/docs/caddyfile/directives/basic_auth

Backend PostgreSQL es nativo. La imagen usa UID65534/GID82 y PHP85; PHP-FPM upstream limpia el entorno pero deja pasar STORAGE_HOST, STORAGE_LOGIN, STORAGE_PASSWORD y CONFIG_PATH. El kit añade únicamente PB_PUBLIC_URL al entorno permitido de PHP-FPM. No se desactiva clear_env. La configuración INI expande variables en proceso; no se escribe una copia con contraseña en disco.

Imágenes Docker se descargan desde registros; no se redistribuyen dentro del ZIP. Se incluye LICENSE-PrivateBin.txt original y se preserva interfaz/créditos upstream.
