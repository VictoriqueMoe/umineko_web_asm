#!/bin/sh
/usr/local/bin/generate-manifest.sh
exec nginx -g 'daemon off;'
