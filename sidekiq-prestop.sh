#!/bin/sh
# bin/sidekiq-prestop.sh
#
# Called by the Kubernetes preStop hook.
# 1. Puts Sidekiq into quiet mode (stop fetching new jobs).
# 2. Waits until this pod has no busy jobs, or until MAX_WAIT runs out.
#
# MAX_WAIT must be lower than terminationGracePeriodSeconds minus the
# Sidekiq shutdown timeout, or Kubernetes will SIGKILL us mid-drain.

set -u

MAX_WAIT="${SIDEKIQ_DRAIN_SECONDS:-540}"
INTERVAL=5

log() {
  # Write to PID 1's stdout so the message shows up in `kubectl logs`.
  echo "[prestop] $(date -u +%H:%M:%S) $*" > /proc/1/fd/1
}

log "sending TSTP to Sidekiq (quiet mode)"
kill -TSTP 1

waited=0
while [ "$waited" -lt "$MAX_WAIT" ]; do
  busy=$(bundle exec ruby -e '
    require "sidekiq/api"
    me = Sidekiq::ProcessSet.new.find { |p| p["hostname"] == ENV["HOSTNAME"] }
    puts(me ? me["busy"].to_i : 0)
  ' 2>/dev/null)

  busy="${busy:-0}"

  if [ "$busy" -eq 0 ]; then
    log "no busy jobs after ${waited}s, letting shutdown continue"
    exit 0
  fi

  log "still ${busy} busy job(s), waited ${waited}s of ${MAX_WAIT}s"
  sleep "$INTERVAL"
  waited=$((waited + INTERVAL))
done

log "drain timeout reached with jobs still running, continuing shutdown"
exit 0
