#!/bin/bash

# =============================
#  DETECTOR DE ESCANEOS + BLOQUEO
# =============================

mkdir -p logs_escaneos
logdir="./logs_escaneos"

# Archivo general de detecciones en vivo
touch "$logdir/live_detect.log"
touch "$logdir/bloqueos.log"

# --- Detectar interfaces ---
echo "🔍 Detectando interfaces disponibles..."
IFS=$'\n'
interfaces=( $(ip -o link show | awk -F': ' '{print $2}') )

echo ""
echo "Interfaces encontradas:"
echo "------------------------"
i=1
for iface in "${interfaces[@]}"; do
    echo "$i) $iface"
    ((i++))
done

echo ""
read -p "👉 Selecciona el número de la interfaz a monitorear: " opt

iface="${interfaces[$((opt-1))]}"
echo "👍 Interfaz seleccionada: $iface"
echo ""

sleep 2
clear

# -------------------------------
# FUNCION DE BLOQUEO DE IP
# -------------------------------
bloquear_ip() {
    ip="$1"
    tipo="$2"
    tiempo=$(date +"%Y-%m-%d %H:%M:%S")

    # Evitar bloqueos duplicados
    if sudo iptables -C INPUT -s "$ip" -j DROP 2>/dev/null; then
        echo "[$tiempo] ✔️ IP ya estaba bloqueada: $ip ($tipo)" | tee -a "$logdir/bloqueos.log"
        return
    fi

    # Aplicar bloqueo
    sudo iptables -A INPUT -s "$ip" -j DROP

    echo "[$tiempo] ⛔ IP bloqueada: $ip — Motivo: $tipo" | tee -a "$logdir/bloqueos.log"
}

# -------------------------------
# FUNCION DE DETECCIÓN
# -------------------------------
detectar_eventos() {
    packet="$1"
    tiempo=$(date +"%Y-%m-%d %H:%M:%S")
    ATTACKER_IP=$(echo "$packet" | awk '{print $3}' | cut -d'.' -f1-4 | sed 's/://')

    # Validar IP detectada
    if [[ -z "$ATTACKER_IP" || "$ATTACKER_IP" == "0.0.0.0" ]]; then
        return
    fi

    # SYN Scan
    if echo "$packet" | grep -q "Flags \[S\]"; then
        echo "[$tiempo] ⚠️ SYN Scan detectado desde $ATTACKER_IP" | tee -a "$logdir/syn_scan.log"
        bloquear_ip "$ATTACKER_IP" "SYN Scan"
    fi

    # NULL Scan (sin flags)
    if echo "$packet" | grep -q "Flags \[\]"; then
        echo "[$tiempo] ⚠️ NULL Scan detectado desde $ATTACKER_IP" | tee -a "$logdir/null_scan.log"
        bloquear_ip "$ATTACKER_IP" "NULL Scan"
    fi

    # FIN Scan
    if echo "$packet" | grep -q "Flags \[F\]"; then
        echo "[$tiempo] ⚠️ FIN Scan detectado desde $ATTACKER_IP" | tee -a "$logdir/fin_scan.log"
        bloquear_ip "$ATTACKER_IP" "FIN Scan"
    fi

    # XMAS Scan (FPU)
    if echo "$packet" | grep -q "Flags \[FPU\]"; then
        echo "[$tiempo] 🎄 XMAS Scan detectado desde $ATTACKER_IP" | tee -a "$logdir/xmas_scan.log"
        bloquear_ip "$ATTACKER_IP" "XMAS Scan"
    fi

    # UDP Scan
    if echo "$packet" | grep -q "UDP"; then
        echo "[$tiempo] 🔵 UDP Scan posible desde $ATTACKER_IP" | tee -a "$logdir/udp_scan.log"
        bloquear_ip "$ATTACKER_IP" "UDP Scan"
    fi

    # ICMP Sweep
    if echo "$packet" | grep -q "ICMP echo request"; then
        echo "[$tiempo] 🟡 ICMP Ping Sweep detectado desde $ATTACKER_IP" | tee -a "$logdir/icmp_sweep.log"
        bloquear_ip "$ATTACKER_IP" "ICMP Sweep"
    fi

    # TCP Connect Scan
    if echo "$packet" | grep -q "Flags \[S.\]"; then
        echo "[$tiempo] 🔑 TCP Connect Scan detectado desde $ATTACKER_IP" | tee -a "$logdir/connect_scan.log"
        bloquear_ip "$ATTACKER_IP" "TCP Connect Scan"
    fi
}

# -------------------------------
# MONITOREO EN VIVO CON TCPDUMP
# -------------------------------
echo "📡 Iniciando monitoreo reactivo en la interfaz: $iface"
echo "Presiona CTRL + C para detener."

sudo tcpdump -i "$iface" -nn --immediate-mode -l | while read -r line; do
    detectar_eventos "$line"
done
