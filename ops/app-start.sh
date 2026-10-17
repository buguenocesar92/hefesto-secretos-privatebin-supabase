#!/bin/sh
set -eu
php85 /opt/hefesto/validate.php
exec /etc/init.d/rc.local
