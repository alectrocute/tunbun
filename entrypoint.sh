#!/bin/sh
# tunbun: configure frp purely from environment; ephemeral TOML in /tmp only.

set -eu

RUNTIME_CONF="${TUNBUN_RUNTIME_CONF:-/tmp/tunbun-frp.toml}"
MODE="${TUNBUN_MODE:-server}"

toml_escape() {
  # Minimal TOML basic string escape for double-quoted values.
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

collect_ipv4() {
  if command -v ip >/dev/null 2>&1; then
    ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1
  fi
  if command -v hostname >/dev/null 2>&1; then
    hostname -i 2>/dev/null | tr ' ' '\n'
  fi
}

print_server_banner() {
  bind_port="${TUNBUN_BIND_PORT:-7000}"
  vhost_http="${TUNBUN_VHOST_HTTP_PORT:-80}"
  vhost_https="${TUNBUN_VHOST_HTTPS_PORT:-443}"
  dash_port="${TUNBUN_DASHBOARD_PORT:-7500}"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " tunbun server (frps) — copy these values for your client env"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " frp control port (TUNBUN_SERVER_PORT): ${bind_port}"
  echo " HTTP vhost port (bunny / load balancer → this port): ${vhost_http}"
  echo " HTTPS vhost port: ${vhost_https}"
  if [ "${dash_port}" != "0" ]; then
    echo " Dashboard (frps UI) port: ${dash_port}"
  fi
  echo ""
  echo " IPv4 addresses seen inside this container:"
  collect_ipv4 | sort -u | sed '/^$/d' | sed 's/^/   /' || true
  echo ""
  echo " Use your bunny.net Anycast endpoint for the frp control port as"
  echo " TUNBUN_SERVER_ADDR on the client when it differs from the IPs above."
  echo ""
  echo " Client env examples:"
  echo "   TUNBUN_MODE=client"
  echo "   TUNBUN_SERVER_ADDR=<hostname-or-ip-from-bunny>"
  echo "   TUNBUN_SERVER_PORT=${bind_port}"
  if [ -n "${TUNBUN_TOKEN:-}" ]; then
    echo "   TUNBUN_TOKEN=<same secret as server>"
  else
    echo "   (optional) TUNBUN_TOKEN=<shared secret> — recommended for production"
  fi
  echo "   TUNBUN_LOCAL_PORT_TO_FQDN=8080:app-xyz.bunny.run,3000:api-xyz.bunny.run"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

write_frps_toml() {
  bind_port="${TUNBUN_BIND_PORT:-7000}"
  vhost_http="${TUNBUN_VHOST_HTTP_PORT:-80}"
  vhost_https="${TUNBUN_VHOST_HTTPS_PORT:-443}"
  dash_port="${TUNBUN_DASHBOARD_PORT:-7500}"
  dash_user="${TUNBUN_DASHBOARD_USER:-admin}"
  dash_pass="${TUNBUN_DASHBOARD_PASSWORD:-admin}"

  {
    printf 'bindAddr = "0.0.0.0"\n'
    printf 'bindPort = %s\n' "$bind_port"
    printf 'vhostHTTPPort = %s\n' "$vhost_http"
    printf 'vhostHTTPSPort = %s\n' "$vhost_https"

    if [ -n "${TUNBUN_TOKEN:-}" ]; then
      printf 'auth.method = "token"\n'
      printf 'auth.token = "%s"\n' "$(toml_escape "$TUNBUN_TOKEN")"
    fi

    if [ "${dash_port}" != "0" ]; then
      printf 'webServer.addr = "0.0.0.0"\n'
      printf 'webServer.port = %s\n' "$dash_port"
      printf 'webServer.user = "%s"\n' "$(toml_escape "$dash_user")"
      printf 'webServer.password = "%s"\n' "$(toml_escape "$dash_pass")"
    fi

    printf 'log.to = "console"\n'
    printf 'log.level = "%s"\n' "${TUNBUN_LOG_LEVEL:-info}"
  } >"$RUNTIME_CONF"
}

write_frpc_toml() {
  srv="${TUNBUN_SERVER_ADDR:?TUNBUN_SERVER_ADDR is required for client mode}"
  sport="${TUNBUN_SERVER_PORT:-7000}"
  local_ip="${TUNBUN_LOCAL_IP:-127.0.0.1}"
  proxy_type="${TUNBUN_PROXY_TYPE:-http}"
  mapping="${TUNBUN_LOCAL_PORT_TO_FQDN:?TUNBUN_LOCAL_PORT_TO_FQDN is required for client mode}"
  dash_port="${TUNBUN_DASHBOARD_PORT:-7500}"
  dash_user="${TUNBUN_DASHBOARD_USER:-admin}"
  dash_pass="${TUNBUN_DASHBOARD_PASSWORD:-admin}"

  case "$proxy_type" in
    http|https) ;;
    *) echo "tunbun: TUNBUN_PROXY_TYPE must be http or https (got $proxy_type)" >&2; exit 1 ;;
  esac

  {
    printf 'serverAddr = "%s"\n' "$(toml_escape "$srv")"
    printf 'serverPort = %s\n' "$sport"
    printf 'log.to = "console"\n'
    printf 'log.level = "%s"\n' "${TUNBUN_LOG_LEVEL:-info}"

    if [ -n "${TUNBUN_TOKEN:-}" ]; then
      printf 'auth.method = "token"\n'
      printf 'auth.token = "%s"\n' "$(toml_escape "$TUNBUN_TOKEN")"
    fi

    if [ "${dash_port}" != "0" ]; then
      printf 'webServer.addr = "0.0.0.0"\n'
      printf 'webServer.port = %s\n' "$dash_port"
      printf 'webServer.user = "%s"\n' "$(toml_escape "$dash_user")"
      printf 'webServer.password = "%s"\n' "$(toml_escape "$dash_pass")"
    fi

    # Match frp defaults: TLS to frps (disable only if you know you need legacy TCP).
    if [ "${TUNBUN_FRPC_TLS_ENABLE:-true}" = "false" ]; then
      printf 'transport.tls.enable = false\n'
    fi
  } >"$RUNTIME_CONF"

  idx=0
  old_ifs=$IFS
  IFS=,
  for pair in $mapping; do
    IFS=$old_ifs
    # trim leading/trailing whitespace via parameter expansion (POSIX)
    pair_trim=${pair#"${pair%%[![:space:]]*}"}
    pair_trim=${pair_trim%"${pair_trim##*[![:space:]]}"}
    [ -z "$pair_trim" ] && continue

    port=${pair_trim%%:*}
    fqdn=${pair_trim#*:}
    if [ "$port" = "$pair_trim" ] || [ -z "$fqdn" ]; then
      echo "tunbun: bad mapping (want port:fqdn): $pair" >&2
      exit 1
    fi
    case "$port" in
      ''|*[!0-9]*) echo "tunbun: local port must be numeric: $port" >&2; exit 1 ;;
    esac

    {
      printf '\n[[proxies]]\n'
      printf 'name = "tunbun-%s"\n' "$idx"
      printf 'type = "%s"\n' "$proxy_type"
      printf 'localIP = "%s"\n' "$(toml_escape "$local_ip")"
      printf 'localPort = %s\n' "$port"
      printf 'customDomains = ["%s"]\n' "$(toml_escape "$fqdn")"
    } >>"$RUNTIME_CONF"

    idx=$((idx + 1))
    IFS=,
  done
  IFS=$old_ifs

  if [ "$idx" -eq 0 ]; then
    echo "tunbun: TUNBUN_LOCAL_PORT_TO_FQDN has no entries" >&2
    exit 1
  fi
}

case "$MODE" in
  server)
    write_frps_toml
    print_server_banner
    exec frps -c "$RUNTIME_CONF"
    ;;
  client)
    write_frpc_toml
    exec frpc -c "$RUNTIME_CONF"
    ;;
  *)
    echo "tunbun: TUNBUN_MODE must be server or client (got $MODE)" >&2
    exit 1
    ;;
esac
