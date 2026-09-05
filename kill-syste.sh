#!/usr/bin/env bash
# kill-syste.sh - Monitor mejorado

LOG_DIR="./logs_escaneos"
SERVICE_NAME="bloqueo-continuo.service"
INTERVAL=3

while true; do
    clear
    echo "\n┌──────────────────────────────────────────────┐"
    echo "│   🔥 MONITOR EN VIVO DEL FIREWALL REACTIVO 🔥 │"
    echo "└──────────────────────────────────────────────┘"

    echo "\n📁 Carpeta de logs:"
    if [ ! -d "$LOG_DIR" ]; then
        echo "❌ No existe $LOG_DIR — creando..."
        mkdir -p "$LOG_DIR"
    else
        echo "✔ OK ($LOG_DIR)"
    fi

    echo "\n📜 Últimos eventos registrados:"
    if ls "$LOG_DIR"/*.log >/dev/null 2>&1; then
        tail -n 10 "$LOG_DIR"/*.log
    else
        echo "❌ No hay logs registrados todavía."
    fi

    echo "\n🚫 IPs BLOQUEADAS (INPUT):"
    if sudo iptables -L INPUT -n --line-numbers | grep DROP >/dev/null 2>&1; then
        sudo iptables -L INPUT -n --line-numbers | grep DROP || true
    else
        echo "❌ No hay IPs bloqueadas o no hay reglas DROP visibles."
    fi

    echo "\n📊 Contadores INPUT:"
    sudo iptables -L INPUT -v -n --line-numbers | sed 's/^/   '/ || true

    echo "\n🧾 Estado del servicio: $SERVICE_NAME"
    if systemctl is-active --quiet $SERVICE_NAME; then
        systemctl status --no-pager $SERVICE_NAME -l | sed -n '1,12p'
        echo "\nÚltimas 50 entradas del journal para $SERVICE_NAME:"
        journalctl -u $SERVICE_NAME -n 50 --no-pager | sed 's/^/   '/
    else
        echo "Servicio $SERVICE_NAME no activo. Usa: sudo systemctl start $SERVICE_NAME"
    fi

    echo "\n🧠 Registros del kernel (últimos 10):"
    sudo dmesg | grep -Ei "drop|iptables" | tail -n 10 | sed 's/^/   '/ || true

    echo "\n🔄 Actualizando en ${INTERVAL}s... (CTRL + C para salir)"
    sleep $INTERVAL
done
