#!/bin/sh
# docker-entrypoint.sh
set -e

# ...any setup you need (wait for Redis, load secrets, etc.)

exec "$@"
