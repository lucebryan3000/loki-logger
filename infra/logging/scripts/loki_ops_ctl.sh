#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-status}"
svc="loki-ops.service"
timer="loki-ops.timer"

case "$cmd" in
  start)
    sudo systemctl daemon-reload
    sudo systemctl enable --now "$svc"
    ;;
  stop)
    sudo systemctl disable --now "$svc"
    ;;
  restart)
    sudo systemctl daemon-reload
    sudo systemctl restart "$svc"
    ;;
  status)
    systemctl status "$svc" --no-pager
    ;;
  logs)
    journalctl -u "$svc" --since "2 hours ago" --no-pager | tail -n 200
    ;;
  tail)
    tail -n 200 /home/luce/apps/loki-logging/_build/loki-ops/runtime.log
    ;;
  timer-start)
    sudo systemctl daemon-reload
    sudo systemctl enable --now "$timer"
    ;;
  timer-stop)
    sudo systemctl disable --now "$timer"
    ;;
  timer-status)
    systemctl status "$timer" --no-pager
    ;;
  *)
    echo "usage: $0 {start|stop|restart|status|logs|tail|timer-start|timer-stop|timer-status}"
    exit 2
    ;;
esac
