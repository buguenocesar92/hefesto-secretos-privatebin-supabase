# Política de tratamiento de datos personales — Secretos (Hefesto Studio)

Estado: vigente desde 2026-10-20. Responsable del tratamiento: el cliente que
opera el kit. Este documento describe qué datos guarda el kit, por qué, cuánto
tiempo los retiene y cómo se exercise los derechos del titular (Ley 21.719).

## 1. Qué datos guarda este kit

El kit de secretos (PrivateBin) guarda, por nota:

- **Nota cifrada**: el texto y los adjuntos van cifrados en cliente; el
  servidor guarda el texto cifrado, el vector de inicializacion y la clave
  negociada por el intercambio de claves.
- **Metadatos de la nota**: identificador, fecha de creacion, fecha de
  expiracion (por defecto 7 dias), numero de lecturas, burn (quemar la nota
  tras una lectura) y la direccion IP de quien la crea y la lee.
- **Adjuntos**: archivos adjuntos a la nota, cifrados junto con ella.
- **Cuentas del panel**: usuario, hash de contrasena y rol; ademas el hash
  bcrypt del acceso basico del gateway.
- **Copias locales de respaldo**: `backups/<timestamp>/` con el dump del esquema
  `public` (`public.dump`) y la configuracion del kit.

Una nota de secretos es una comunicacion entre personas: su metadato (IP, fecha, lecturas)
es dato personal de quienes participan.

## 2. Qué datos NO guarda este kit

- El `.env` **no** se copia en claro al respaldo: solo sus nombres de
  variable (`env.vars`) y, si hay un receptor `age` configurado, el `.env`
  cifrado (`env.age`). Ver `docs/CONTRATO-RESPALDO.md`, regla 5.
- El kit **no** descifra las notas: el texto plano nunca llega al servidor.
- El kit no envia notas ni metadatos a servicios de terceros.

## 3. Base legal y deberes

- **Minimización**: el servidor guarda lo minimo para servir la nota: su texto cifrado y su
  metadato. El contenido en claro no existe en el servidor, y la IP se guarda
  porque el kit la usa para las estadisticas de lectura; el operador puede
  reducir la retencion de esos metadatos en la interfaz.
- **Finalidad**: compartir secretos de forma temporal y autocontenida. Los datos no se usan para otros fines ni se ceden a terceros.
- **Seguridad**: los respaldos se cifran en reposo con `age` hacia el destino del operador, la clave privada no está en este servidor, el `.env` nunca sale en claro y las notas van cifradas en cliente.
- **Auditoría**: cada respaldo y cada restauración dejan registro en `logs/restore.log` con origen, sha256 verificado, destino y resultado. Es registro de actividades de tratamiento: no guarda valores de secretos ni el contenido de las notas.

## 4. Retención

| Dato | Dónde | Retención por defecto | Quién lo borra |
|---|---|---|---|
| Notas cifradas y adjuntos | PostgreSQL (`public`) | hasta la expiracion que el usuario fijo (7 dias por defecto) | el usuario, desde la interfaz |
| Metadatos (IP, lecturas, fechas) | PostgreSQL (`public`) | mientras exista la nota | el usuario o el operador |
| Cuentas del panel | PostgreSQL (`public`) | mientras la cuenta exista | el operador |
| Respaldos en disco | `backups/<timestamp>/` | **a definir por el operador**; el kit no borra nada por su cuenta | el operador |
| Registro de auditoría | `logs/restore.log` | append-only; se trunca por política del cliente | el operador |

**El kit no borra respaldos ni datos por su cuenta.** Borrar es una decisión del
operador, porque un respaldo borrado no se recupera.

## 5. Derechos del titular (acceso, rectificación y supresión)

El cliente que opera el kit debe poder atender las solicitudes de las
personas que participan en un intercambio de notas:

1. **Acceso**: el emisor de la nota es el unico que puede leerla; para una
   solicitud de acceso, el operador entrega solo los metadatos de la nota
   (fechas, IP) y el texto solo si el titular lo autoriza, porque el servidor
   no lo tiene en claro.
2. **Rectificación**: quien creo la nota puede quemarla o cambiar su
   expiracion.
3. **Supresión**: eliminar la nota y los respaldos que la contengan, y dejar
   constancia en el registro de auditoria.
4. **Revocación del consentimiento**: si el titular pide la eliminacion, se
   borra la nota aunque no haya expirado.

El kit garantiza que el contenido no existe en claro en el servidor y que las
notas expiradas se pueden eliminar.

## 6. Verificación

- `bats tests/backup_restore.bats` comprueba, con datos sintéticos, que el
  `.env` no queda en claro, que el manifiesto lleva las cinco claves, que un
  artefacto alterado se rechaza y que un destino no vacío aborta la
  restauración.
- `gitleaks` corre en CI sobre el repositorio y su historial.
