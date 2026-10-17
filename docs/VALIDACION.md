# Validación realizada
Fecha: 2026-10-16. Kit PrivateBin 2.0.6.

Comprobado localmente:
- Sintaxis Python por AST y shell con sh -n; parseo de ambos YAML y de la estructura INI.
- Imágenes fijadas por digest y ausencia de puertos de host en Compose base.
- configure.py crea .env con 0600, genera clave aleatoria y rechaza sobrescritura sin cambiar el archivo.
- Integridad de respaldos: manifiesto, SHA-256, rechazo de archivo alterado, symlink y lista de rutas inesperada.
- Con un ejecutable Docker simulado en carpeta temporal: secuencia pausa/copia/reinicio, reinicio tras fallo del dump, ausencia de manifiesto completed en copia fallida; rechazo de restauración con app activa/base no vacía/sin reconocimiento de recuperación de notas; filtrado de entrada SCHEMA public en la lista de restauración.
- Integridad ZIP, sin .env real, claves, certificados reales ni respaldos.

Las simulaciones verifican lógica de scripts y protecciones locales; NO ejecutan Docker, PostgreSQL, pg_dump, pg_restore ni la aplicación. PHP no está disponible aquí: validate.php no recibió un lint ni ejecución PHP. Tampoco se validó Caddy con su binario.

Pendiente obligatorio en el entorno de prueba: Compose config y arranque real, CA y verify-full, permisos de rol, migraciones/tablas de PrivateBin, expansión de entorno en PHP-FPM, cifrado/descifrado del navegador, Basic Auth, HTTPS, consumo de una lectura, caducidad, restauración real en otro proyecto y pruebas móvil/cliente. Usar docs/ACEPTACION.md.

No hay servicio publicado, proyecto Supabase creado, dominio configurado, integración Odoo instalada, contrato ni facturación activados por esta entrega.
