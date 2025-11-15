#!/bin/bash

LOG_DIR="./logs_escaneos"
INTERVALO=3   # Refresco cada 3 segundos. Puedes cambiarlo.

while true; do
    clear
    echo -e "\n┌──────────────────────────────────────────────┐"
    echo -e   "│   🔥 MONITOR EN VIVO DEL FIREWALL REACTIVO 🔥 │"
    echo -e   "└──────────────────────────────────────────────┘"

    # ----------------------------------------
    # 1. Verificar carpeta de logs
    # ----------------------------------------
    echo -e "\n📁 Carpeta de logs:"
    if [ ! -d "$LOG_DIR" ]; then
        echo "❌ No existe $LOG_DIR — creando..."
        mkdir -p "$LOG_DIR"
    else
        echo "✔ OK ($LOG_DIR)"
    fi

    # ----------------------------------------
    # 2. Últimos eventos detectados
    # ----------------------------------------
    echo -e "\n📜 Últimos eventos registrados:"
    if ls "$LOG_DIR"/*.log >/dev/null 2>&1; then
        tail -n 10 "$LOG_DIR"/*.log
    else
        echo "❌ No hay logs registrados todavía."
    fi

    # ----------------------------------------
    # 3. Mostrar IPs bloqueadas
    # ----------------------------------------
    echo -e "\n🚫 IPs BLOQUEADAS (INPUT):"
    sudo iptables -L INPUT -n --line-numbers | grep DROP || echo "❌ No hay IPs bloqueadas."

    # ----------------------------------------
    # 4. Contadores de INPUT
    # ----------------------------------------
    echo -e "\n📊 Contadores INPUT:"
    sudo iptables -L INPUT -v -n --line-numbers | sed 's/^/   /'


    # ----------------------------------------
    # 6. Mensajes del Kernel relacionados a DROP
    # ----------------------------------------
    echo -e "\n🧠 Registros del kernel (últimos 10):"
    sudo dmesg | grep -Ei "drop|iptables" | tail -n 10 | sed 's/^/   /'

    # ----------------------------------------
    echo -e "\n🔄 Actualizando en ${INTERVALO}s... (CTRL + C para salir)"
    sleep $INTERVALO
done
