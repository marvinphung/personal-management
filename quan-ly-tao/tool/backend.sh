#!/bin/zsh
set -euo pipefail

script_path=${0:A}
repo_dir=${script_path:h:h}
installer="${repo_dir}/deploy/macos/install_launchdaemons.sh"
health_local=http://127.0.0.1:8001/v1/health/ready
health_public=https://api.xn--qun-l-tao-49a0064f.id.vn/v1/health/ready
labels=(
  sh.brew.postgresql@17
  app.quanlytao.local-nats
  app.quanlytao.local-backend
  app.quanlytao.cloudflared
)

usage() {
  print "Usage: ./tool/backend.sh {install|start|restart|stop|status|health|logs}"
}

wait_for_health() {
  local attempt
  for attempt in {1..30}; do
    if curl --fail --silent --show-error --max-time 3 "${health_local}" >/dev/null 2>&1; then
      curl --fail --silent --show-error --max-time 10 "${health_local}"
      print
      curl --fail --silent --show-error --max-time 15 "${health_public}"
      print
      return 0
    fi
    sleep 1
  done
  print -u2 "Backend did not become ready within 30 seconds."
  return 1
}

require_root() {
  if [[ ${EUID} -ne 0 ]]; then
    exec sudo "${script_path}" "$@"
  fi
}

action=${1:-status}
case "${action}" in
  install)
    require_root "$@"
    "${installer}"
    wait_for_health
    ;;
  start)
    require_root "$@"
    for label in ${labels}; do
      launchctl enable "system/${label}"
      launchctl kickstart "system/${label}"
    done
    wait_for_health
    ;;
  restart)
    require_root "$@"
    for label in ${labels}; do
      launchctl kickstart -k "system/${label}"
    done
    wait_for_health
    ;;
  stop)
    require_root "$@"
    for label in app.quanlytao.cloudflared app.quanlytao.local-backend app.quanlytao.local-nats sh.brew.postgresql@17; do
      launchctl kill SIGTERM "system/${label}" 2>/dev/null || true
      launchctl disable "system/${label}"
    done
    print "Backend stack stopped and disabled. Run './tool/backend.sh start' to enable it again."
    ;;
  status)
    for label in ${labels}; do
      if launchctl print "system/${label}" >/dev/null 2>&1; then
        print "RUNNING/LOADED  ${label}"
      else
        print "NOT LOADED      ${label}"
      fi
    done
    "${script_path}" health
    ;;
  health)
    curl --fail --silent --show-error --max-time 10 "${health_local}"
    print
    curl --fail --silent --show-error --max-time 15 "${health_public}"
    print
    ;;
  logs)
    print "Backend:    /Users/Shared/quanlytao-local/logs/backend.stderr.log"
    print "NATS:       /Users/Shared/quanlytao-local/logs/nats.stderr.log"
    print "Cloudflare: /Users/Shared/quanlytao-local/logs/cloudflared.stderr.log"
    print "PostgreSQL: /opt/homebrew/var/log/postgresql@17.log"
    ;;
  *)
    usage
    exit 2
    ;;
esac
