#!/bin/sh
# Executado como root em container descartável, sem rede externa ou aplicação real.
set -eu

request() {
    curl --connect-timeout 2 --max-time 10 "$@"
}

dpkg --compare-versions "$(dpkg-query -W -f='${Version}' nginx)" ge 1.30.6
nginx -v
mkdir -p /var/www/public /etc/nginx/ssl
cat > /var/www/public/index.php <<'PHP'
<?php
header('Content-Type: application/json');
echo json_encode(['sapi' => PHP_SAPI, 'uri' => $_SERVER['REQUEST_URI'], 'value' => $_GET['value'] ?? null]);
PHP
printf 'static fixture\n' > /var/www/public/probe.css
printf 'private fixture\n' > /var/www/public/.probe-secret

openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj /CN=localhost \
    -keyout /etc/nginx/ssl/ssl.key.pem -out /etc/nginx/ssl/ssl.crt.pem >/dev/null 2>&1
cp /usr/local/docker/nginx/ssl.conf /etc/nginx/ssl/probe.conf
cp /usr/local/docker/nginx/dhparams.pem /etc/nginx/ssl/dhparams.pem
nginx -t

/bin/entrypoint.sh >/tmp/app-startup.log 2>&1 &
startup_pid=$!
trap 'kill "$startup_pid" 2>/dev/null || true' EXIT
ready=false
for attempt in $(seq 1 30); do
    if request --fail --silent http://localhost/index.php >/dev/null; then
        ready=true
        break
    fi
    sleep 1
done
if [ "$ready" != true ]; then
    cat /tmp/app-startup.log
    exit 1
fi

response=$(request --fail --silent 'http://localhost/probe/route?value=hello')
test "$response" = '{"sapi":"fpm-fcgi","uri":"\/probe\/route?value=hello","value":"hello"}'
test "$(request --fail --silent http://localhost/probe.css)" = 'static fixture'
request --fail --silent --head http://localhost/probe.css | grep -qi '^Cache-Control:.*max-age='
test "$(request --silent --output /dev/null --write-out '%{http_code}' http://localhost/.probe-secret)" = 403
test "$(request --fail --silent --insecure --http2 --output /dev/null --write-out '%{http_version}' https://localhost/probe.css)" = 2
test "$(request --fail --silent --insecure 'https://localhost/probe/route?value=hello')" = "$response"
kill -0 "$startup_pid"
printf 'Nginx: entrypoint/supervisor, PHP-FPM, rota/query, estáticos/cache, arquivos privados e TLS/HTTP2 passaram.\n'
