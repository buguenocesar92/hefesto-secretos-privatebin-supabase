;<?php http_response_code(403); /*
; Configuracion nativa PrivateBin. Las credenciales se expanden desde el entorno.
[main]
name = "Hefesto Secretos"
basepath = "${PB_PUBLIC_URL}"
discussion = false
opendiscussion = false
password = true
fileupload = false
burnafterreadingselected = true
defaultformatter = "plaintext"
sizelimit = 102400
templateselection = false
template = "bootstrap5"
languageselection = false
languagedefault = "es"
qrcode = false
email = false
icon = "none"
httpwarning = true
compression = "zlib"
notice = "Para entregas temporales. Guarda la contraseña adicional por otro canal. No uses este servicio como tu única copia."
[expire]
default = "1hour"
[expire_options]
5min = 300
10min = 600
1hour = 3600
1day = 86400
[formatter_options]
plaintext = "Texto plano"
[traffic]
limit = 10
; No confiar en X-Forwarded-For: limite conservador compartido por el gateway.
[purge]
limit = 300
batchsize = 100
[model]
class = Database
[model_options]
dsn = "pgsql:host=${STORAGE_HOST};port=5432;dbname=postgres;sslmode=verify-full;sslrootcert=/certs/ca.crt;connect_timeout=15"
tbl = "privatebin_"
usr = "${STORAGE_LOGIN}"
pwd = "${STORAGE_PASSWORD}"
opt[12] = false
