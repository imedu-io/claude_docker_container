#!/bin/sh
# Start Squid and tail log files to stdout/stderr so "docker logs" shows them.
# Squid runs as user proxy and cannot write to /dev/stdout directly.

set -e

LOG_DIR=/var/log/squid
touch "${LOG_DIR}/access.log" "${LOG_DIR}/cache.log"
chown proxy:proxy "${LOG_DIR}/access.log" "${LOG_DIR}/cache.log"

# Start squid in background
"$@" &
SQUID_PID=$!

# Tail logs to container stdout/stderr (so docker logs works)
tail -f "${LOG_DIR}/access.log" &
tail -f "${LOG_DIR}/cache.log" 1>&2 &

# Wait for squid; exit with its status
wait $SQUID_PID
