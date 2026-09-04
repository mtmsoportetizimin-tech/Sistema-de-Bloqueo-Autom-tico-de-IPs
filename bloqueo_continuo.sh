#!/usr/bin/env bash
# bloqueo_continuo.sh
# Detector y bloqueador robusto usando ipset + iptables
# Requiere: ipset, iptables, tcpdump, ip (iproute2)
# Lee config.ini (o config.ini.example) y whitelist.txt

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.ini"
[ -f "${CONFIG_FILE}" ] || CONFIG_FILE="${SCRIPT_DIR}/config.ini.example"

# Defaults
INTERFACE=""
IPSET_NAME="auto_firewall_set"
BAN_TIMEOUT=86400    # seconds; 0 = permanent
LOG_DIR="${SCRIPT_DIR}/logs_escaneos"
TCPDUMP_OPTIONS="-nn --immediate-mode"
WHITELIST_PATH="${SCRIPT_DIR}/whitelist.txt"
CLEANUP_ON_EXIT=true

# Load simple INI-like config
if [ -f "$CONFIG_FILE" ]; then
    while IFS='=' read -r key value; do
        key_trim=$(echo "$key" | tr -d ' \t\r')
        value_trim=$(echo "$value" | sed -e 's/^ *//' -e 's/ *$//')
        case "$key_trim" in
            INTERFACE) INTERFACE="$value_trim" ;;
            IPSET_NAME) IPSET_NAME="$value_trim" ;;
            BAN_TIMEOUT) BAN_TIMEOUT="$value_trim" ;;
            LOG_DIR) LOG_DIR="$value_trim" ;;
            TCPDUMP_OPTIONS) TCPDUMP_OPTIONS="$value_trim" ;;
            WHITELIST_PATH) WHITELIST_PATH="$value_trim" ;;
            CLEANUP_ON_EXIT) CLEANUP_ON_EXIT="$value_trim" ;;
        esac
    done < <(grep -v '^\s*#' "$CONFIG_FILE" || true)
fi

mkdir -p "$LOG_DIR"
mkdir -p "$SCRIPT_DIR"

TIMESTAMP() { date +"%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(TIMESTAMP)] $*" | tee -a "$LOG_DIR/auto-firewall.log"; }

usage() {
    cat <<EOF
Uso: sudo $0 [--iface <interfaz>]
Lee configuración desde config.ini (o config.ini.example) y whitelist.txt.
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--iface) INTERFACE="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Argumento desconocido: $1"; usage; exit 1 ;;
    esac
done

if [ -z "$INTERFACE" ]; then
    # try to select first non-loopback interface
    INTERFACE=$(ip -o -4 addr show scope global | awk -F': ' '{print $2}' | head -n1 || true)
fi

if [ -z "$INTERFACE" ]; then
    echo "No se encontró interfaz. Especifica --iface <ifname> o configura INTERFACE en config.ini" >&2
    exit 2
fi

# Ensure running as root for ipset/iptables/tcpdump
if [ "$EUID" -ne 0 ]; then
    echo "Este script requiere privilegios de root. Ejecuta con sudo." >&2
    exit 3
fi

# Load whitelist into associative array
declare -A WHITELIST
if [ -f "$WHITELIST_PATH" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line_trim=$(echo "$line" | sed -e 's/#.*//' -e 's/^ *//' -e 's/ *$//')
        [ -z "$line_trim" ] && continue
        WHITELIST["$line_trim"]=1
    done < "$WHITELIST_PATH"
fi

ipset_exists() {
    ipset list -n | grep -xq "$1"
}

ensure_ipset() {
    if ! ipset_exists "$IPSET_NAME"; then
        if [ "$BAN_TIMEOUT" -gt 0 ]; then
            ipset create "$IPSET_NAME" hash:ip timeout "$BAN_TIMEOUT" -exist
        else
            ipset create "$IPSET_NAME" hash:ip -exist
        fi
        log "Creado ipset: $IPSET_NAME (timeout=$BAN_TIMEOUT)"
    fi
}

ensure_iptables_rule() {
    # Check if a rule exists that DROPs matches from the ipset
    if ! iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP >/dev/null 2>&1; then
        iptables -I INPUT -m set --match-set "$IPSET_NAME" src -j DROP
        log "Añadida regla iptables para bloquear ipset: $IPSET_NAME"
    else
        log "Regla iptables para $IPSET_NAME ya existe"
    fi
}

block_ip() {
    local ip="$1"
    local reason="$2"

    # Skip if in whitelist (support CIDR or single IP)
    for w in "${!WHITELIST[@]}"; do
        if ipcalc -c "$ip" "$w" >/dev/null 2>&1 || [ "$ip" == "$w" ]; then
            log "IP $ip en whitelist ($w) — no se bloqueará"
            return
        fi
    done

    # Add to ipset
    if [ "$BAN_TIMEOUT" -gt 0 ]; then
        ipset add "$IPSET_NAME" "$ip" timeout "$BAN_TIMEOUT" -exist 2>/dev/null || ipset add "$IPSET_NAME" "$ip" -exist
    else
        ipset add "$IPSET_NAME" "$ip" -exist
    fi
    log "⛔ IP bloqueada: $ip — Motivo: $reason"
}

cleanup() {
    log "Recibida señal, limpiando..."
    if [ "$CLEANUP_ON_EXIT" = true ] || [ "$CLEANUP_ON_EXIT" = "true" ]; then
        # Remove iptables rule
        if iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP >/dev/null 2>&1; then
            iptables -D INPUT -m set --match-set "$IPSET_NAME" src -j DROP || true
            log "Regla iptables eliminada"
        fi
        # Destroy ipset
        if ipset_exists "$IPSET_NAME"; then
            ipset destroy "$IPSET_NAME" || true
            log "Ipset $IPSET_NAME destruido"
        fi
    else
        log "CLEANUP_ON_EXIT=false — no se eliminan reglas ni ipset"
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

# Ensure prerequisites
command -v ipset >/dev/null 2>&1 || { echo "ipset no instalado. Instala ipset."; exit 4; }
command -v iptables >/dev/null 2>&1 || { echo "iptables no instalado."; exit 4; }
command -v tcpdump >/dev/null 2>&1 || { echo "tcpdump no instalado."; exit 4; }
command -v ip >/dev/null 2>&1 || { echo "ip (iproute2) no instalado."; exit 4; }
command -v ipcalc >/dev/null 2>&1 || log "ipcalc no encontrado: la comprobación de CIDR en whitelist será limitada"

ensure_ipset
ensure_iptables_rule

log "Iniciando monitoreo en interfaz: $INTERFACE"
log "Opciones tcpdump: $TCPDUMP_OPTIONS"

# Start tcpdump and parse lines
# Use -l to make stdout line buffered, -nn for numeric hosts/ports
tcpdump -i "$INTERFACE" $TCPDUMP_OPTIONS 2>/dev/null | while IFS= read -r line; do
    # Extract all IP-like tokens
    ips=( $(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || true) )
    if [ ${#ips[@]} -lt 1 ]; then
        continue
    fi
    # Heuristic: the first IP is source in many tcpdump formats; otherwise choose the first non-local
    src_ip=""
    for iptok in "${ips[@]}"; do
        # skip localhost/host's IPs (best-effort)
        if [ "$iptok" = "127.0.0.1" ]; then continue; fi
        # skip if equals to interface IPs
        if ip -o -4 addr show "$INTERFACE" | grep -q "$iptok"; then continue; fi
        src_ip="$iptok"
        break
    done
    [ -z "$src_ip" ] && src_ip="${ips[0]}"

    # basic validation
    if [[ ! "$src_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        continue
    fi

    # Detect scan signatures in the tcpdump line
    if echo "$line" | grep -q "Flags \[S\]"; then
        block_ip "$src_ip" "SYN Scan"
    elif echo "$line" | grep -q "Flags \[F\]"; then
        block_ip "$src_ip" "FIN Scan"
    elif echo "$line" | grep -q "Flags \[FPU\]"; then
        block_ip "$src_ip" "XMAS Scan"
    elif echo "$line" | grep -q "Flags \[S.\]"; then
        block_ip "$src_ip" "TCP Connect Scan"
    elif echo "$line" | grep -qi "udp"; then
        block_ip "$src_ip" "UDP Scan"
    elif echo "$line" | grep -qi "icmp"; then
        block_ip "$src_ip" "ICMP Sweep"
    fi

    # write raw event to live_detect.log
    echo "[$(TIMESTAMP)] $line" >> "$LOG_DIR/live_detect.log"
done
