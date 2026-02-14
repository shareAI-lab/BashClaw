#!/usr/bin/env bash
# Daemon management command for bashclaw

cmd_daemon() {
  local subcommand="${1:-}"
  shift 2>/dev/null || true

  case "$subcommand" in
    install)  _cmd_daemon_install "$@" ;;
    uninstall) _cmd_daemon_uninstall ;;
    status)   _cmd_daemon_status ;;
    logs)     _cmd_daemon_logs "$@" ;;
    restart)  _cmd_daemon_restart ;;
    stop)     _cmd_daemon_stop ;;
    -h|--help|help|"") _cmd_daemon_usage ;;
    *) log_error "Unknown daemon subcommand: $subcommand"; _cmd_daemon_usage; return 1 ;;
  esac
}

_cmd_daemon_install() {
  local enable=false
  local port=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --enable) enable=true; shift ;;
      --port) port="$2"; shift 2 ;;
      -h|--help) _cmd_daemon_usage; return 0 ;;
      *) log_error "Unknown option: $1"; return 1 ;;
    esac
  done

  daemon_install "$port" "$enable"
}

_cmd_daemon_uninstall() {
  daemon_uninstall
}

_cmd_daemon_status() {
  daemon_status
}

_cmd_daemon_logs() {
  daemon_logs "$@"
}

_cmd_daemon_restart() {
  daemon_restart
}

_cmd_daemon_stop() {
  daemon_stop
}

_cmd_daemon_usage() {
  cat <<'EOF'
Usage: bashclaw daemon <subcommand> [options]

Subcommands:
  install      Install as system service
  uninstall    Remove system service
  status       Show daemon status
  logs         Show daemon logs
  restart      Restart the daemon
  stop         Stop the daemon

Install options:
  --enable        Enable and start immediately
  --port PORT     Override gateway port

Logs options:
  -f, --follow    Follow log output (tail -f)
  -n, --lines N   Number of lines to show (default: 50)

Supported platforms:
  macOS       LaunchAgent (~/Library/LaunchAgents/)
  Linux       systemd user service (~/.config/systemd/user/)
  Linux       crontab @reboot fallback
  Termux      ~/.termux/boot/ (requires Termux:Boot app)

Examples:
  bashclaw daemon install --enable
  bashclaw daemon install --enable --port 8080
  bashclaw daemon status
  bashclaw daemon logs -f
  bashclaw daemon stop
  bashclaw daemon uninstall
EOF
}
