#!/bin/zsh
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  print -u2 "Run this installer with sudo."
  exit 1
fi

source_dir=${0:A:h}/launchdaemons
target_dir=/Library/LaunchDaemons
log_dir=/Users/Shared/quanlytao-local/logs
labels=(
  sh.brew.postgresql@17
  app.quanlytao.local-nats
  app.quanlytao.local-backend
  app.quanlytao.cloudflared
)

install -d -o fendee -g staff -m 0750 "${log_dir}"

# Avoid two launchd jobs managing the same PostgreSQL data directory.
launchctl bootout "gui/501/sh.brew.postgresql@17" 2>/dev/null || true

for label in ${labels}; do
  source_plist="${source_dir}/${label}.plist"
  target_plist="${target_dir}/${label}.plist"
  plutil -lint "${source_plist}" >/dev/null
  launchctl bootout "system/${label}" 2>/dev/null || true
  install -o root -g wheel -m 0644 "${source_plist}" "${target_plist}"
  launchctl enable "system/${label}"
  launchctl bootstrap system "${target_plist}"
done

for label in ${labels}; do
  launchctl kickstart -k "system/${label}"
done

print "Installed Quan Ly Tao boot services."
print "Verify with: sudo launchctl print system/app.quanlytao.local-backend"
print "Health check: curl -f http://127.0.0.1:8001/v1/health/ready"
