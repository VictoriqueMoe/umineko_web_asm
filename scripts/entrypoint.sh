#!/bin/sh
/usr/local/bin/generate-manifest.sh
/usr/local/bin/convert-assets.sh /usr/share/nginx/html/game /usr/share/nginx/html/cache/game &
exec nginx -g 'daemon off;'
