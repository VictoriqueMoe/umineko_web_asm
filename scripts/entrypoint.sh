#!/bin/sh
/usr/local/bin/generate-manifest.sh
if [ "$HOSTING_MODE" != "local" ]; then
    nice -n 19 ionice -c 3 -n 7 /usr/local/bin/convert-assets.sh /usr/share/nginx/html/game /usr/share/nginx/html/cache/game &
fi
exec nginx -g 'daemon off;'
