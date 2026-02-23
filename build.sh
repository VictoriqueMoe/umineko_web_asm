#!/bin/bash
docker compose build --build-arg ONS_CACHE_BUST=$(date +%s)
docker compose up -d
