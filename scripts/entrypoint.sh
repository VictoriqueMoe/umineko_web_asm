#!/bin/sh
echo "{\"hostingMode\":\"${HOSTING_MODE:-local}\"}" > /usr/share/nginx/html/config.json
if [ -n "$SITE_URL" ]; then
    sed -i "s|__SITE_URL__|${SITE_URL}|g" /usr/share/nginx/html/index.html
fi
if [ "$HOSTING_MODE" != "remote" ]; then
    /usr/local/bin/generate-manifest.sh
fi
if [ "$HOSTING_MODE" = "production" ]; then
    nice -n 19 ionice -c 3 -n 7 /usr/local/bin/convert-assets.sh /usr/share/nginx/html/game /usr/share/nginx/html/cache/game &
fi
exec nginx -g 'daemon off;'
