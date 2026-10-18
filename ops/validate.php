<?php
// Validar sin imprimir valores de credenciales ni DSN.
function stop_invalid($message) { fwrite(STDERR, $message . PHP_EOL); exit(1); }
$host = getenv('STORAGE_HOST');
if (!is_string($host) || !preg_match('/^[a-zA-Z0-9][a-zA-Z0-9.-]+$/D', $host) || strpos($host, 'REEMPLAZAR') !== false) stop_invalid('Configurar host PostgreSQL valido');
$user = getenv('STORAGE_LOGIN');
if (!is_string($user) || !preg_match('/^privatebin_app(?:\.[a-z0-9]+)?$/D', $user)) stop_invalid('Usar rol privatebin_app o privatebin_app.projectref');
$pwd = getenv('STORAGE_PASSWORD');
if (!is_string($pwd) || !preg_match('/^[a-f0-9]{64}$/D', $pwd)) stop_invalid('Usar clave DB hexadecimal de 64 caracteres generada por configure.py');
$dbname = (string) getenv('STORAGE_DBNAME');
if (!preg_match('/^[a-zA-Z_][a-zA-Z0-9_]{0,62}$/D', $dbname)) stop_invalid('STORAGE_DBNAME invalido (identificador PostgreSQL)');
$sslmode = strtolower((string) getenv('STORAGE_SSLMODE'));
if ($sslmode === '') $sslmode = 'verify-full';
$allowed_modes = ['disable', 'allow', 'prefer', 'require', 'verify-ca', 'verify-full'];
if (!in_array($sslmode, $allowed_modes, true)) stop_invalid('STORAGE_SSLMODE invalido');
$sslrootcert = (string) getenv('STORAGE_SSLROOTCERT');
if ($sslrootcert === '') $sslrootcert = '/certs/ca.crt';
if (!preg_match('#^/certs/[A-Za-z0-9._/-]{1,248}$#D', $sslrootcert)) stop_invalid('STORAGE_SSLROOTCERT debe estar bajo /certs/');
if (strpos($sslrootcert, '..') !== false) stop_invalid('STORAGE_SSLROOTCERT no admite segmentos ..');
$url = getenv('PB_PUBLIC_URL');
$local = getenv('LOCAL_PREVIEW') === 'true';
if (!is_string($url) || !filter_var($url, FILTER_VALIDATE_URL)) stop_invalid('URL invalida');
$p = parse_url($url);
if (isset($p['user']) || isset($p['pass']) || isset($p['query']) || isset($p['fragment']) || ($p['path'] ?? '') !== '/') stop_invalid('Usar dominio raiz con barra final, sin parametros');
if (($p['scheme'] ?? '') !== 'https' && !($local && $url === 'http://localhost:8110/')) stop_invalid('HTTPS obligatorio fuera de localhost autorizado');
if (in_array($sslmode, ['verify-full', 'verify-ca'], true)) {
  if (!is_readable($sslrootcert) || filesize($sslrootcert) < 100) stop_invalid('Falta CA PostgreSQL en ' . $sslrootcert);
}
if (!extension_loaded('pdo_pgsql')) stop_invalid('Falta PDO PostgreSQL');
$cfg = parse_ini_file('/srv/cfg/conf.php', true);
if (!$cfg || ($cfg['model']['class'] ?? '') !== 'Database' || ($cfg['model_options']['pwd'] ?? '') !== $pwd || ($cfg['main']['basepath'] ?? '') !== $url) stop_invalid('Configuracion INI o variables invalidas');
echo "Configuracion PrivateBin validada; inicio nativo." . PHP_EOL;
