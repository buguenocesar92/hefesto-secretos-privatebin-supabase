# Entrega a cliente
Entregables: dominio, administrador responsable, política de caducidad/retención, credenciales Basic Auth por canal privado, repositorio del kit sin .env, ubicación cifrada del respaldo y registro de aceptación.

Flujo sugerido para soporte: crear nota con contraseña adicional y quemar activado; enviar enlace al destinatario previsto; enviar contraseña por otro canal; confirmar recepción sin copiar el secreto al ticket; rotar las credenciales entregadas cuando corresponda. El enlace también es sensible aunque no contenga el texto visible.

En Odoo se puede registrar responsable, fecha y estado de la entrega sin guardar el secreto. Los enlaces pueden guardarse en un registro con acceso restringido si la política del cliente lo permite. No hay conector Odoo/n8n instalado ni API REST con tokens desarrollada por este kit. PrivateBin conserva su protocolo nativo de contenido cifrado; no automatizar texto plano hacia el servidor ni modificar el cifrado para fabricar un CRUD genérico.

Oferta comercial: instalación, dominio/TLS, operación, capacitación y soporte. La marca Hefesto identifica el servicio; el motor es PrivateBin, con atribución y licencias originales conservadas. Los secretos permanentes deben ir a una bóveda. No hay pagos ni suscripciones activados.

Actualización: respaldo, revisión de notas de versión y avisos upstream, cambiar tag y digest juntos en copia aislada, ejecutar aceptación antes de recrear producción. Las migraciones automáticas de DB pueden impedir volver a una imagen anterior sin restaurar una copia. Conservar kit y respaldo de la misma versión.
