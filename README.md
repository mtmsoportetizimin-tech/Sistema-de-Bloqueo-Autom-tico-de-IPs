🛠 1. Requisitos

Antes de ejecutar el script asegúrate de tener instalado:

sudo apt update
sudo apt install -y iptables net-tools tcpdump bash


Permisos necesarios:

Usuario con privilegios sudo

Acceso a la interfaz de red a monitorear

📂 2. Archivos del proyecto
auto-firewall/
│
├── bloqueo_continuo.sh   # Script principal de bloqueo automático
├── lista_bloqueo.txt     # IPs detectadas o manualmente añadidas
└── README.md             # Este manual

🚀 3. Instalación

Clona el repositorio:

git clone https://github.com/usuario/auto-firewall.git
cd auto-firewall


Dale permisos de ejecución:

chmod +x bloqueo_continuo.sh

▶️ 4. Uso básico

Ejecuta el script indicando la interfaz:

sudo ./bloqueo_continuo.sh wlx502b73a90122


El script:

✔ Monitorea tráfico real
✔ Detecta IPs sospechosas
✔ Las bloquea con iptables
✔ Agrega las IPs a lista_bloqueo.txt
✔ Mantiene el proceso en ejecución continua

🔍 5. Verificación de bloqueos
Ver todas las IP bloqueadas:
sudo iptables -L INPUT -n --line-numbers

Ver reglas generadas por el script:
grep "BLOQUEADO_AUTO" /var/log/syslog

Ver archivo con las IPs detectadas:
cat lista_bloqueo.txt

🔁 6. Ejecución continua en segundo plano

Ejecutar el script como servicio:

nohup sudo ./bloqueo_continuo.sh wlx502b73a90122 &


Ver si sigue corriendo:

ps aux | grep bloqueo_continuo


Detenerlo:

sudo kill -9 <PID>

🔧 7. Configurar como servicio systemd (opcional)

Crea el archivo:

sudo nano /etc/systemd/system/bloqueo-auto.service


Contenido:

[Unit]
Description=Bloqueo Automático de IPs
After=network.target

[Service]
ExecStart=/ruta/completa/bloqueo_continuo.sh wlx502b73a90122
Restart=always

[Install]
WantedBy=multi-user.target


Activar:

sudo systemctl daemon-reload
sudo systemctl enable bloqueo-auto.service
sudo systemctl start bloqueo-auto.service


Estado:

sudo systemctl status bloqueo-auto.service

📜 8. Script completo (para el README)

Colócalo en bloqueo_continuo.sh

#!/bin/bash

# ───────────────────────────────────────────────
#  SISTEMA AUTOMÁTICO DE BLOQUEO CONTINUO DE IPS
# ───────────────────────────────────────────────

IFACE="$1"
LOG="lista_bloqueo.txt"

if [ -z "$IFACE" ]; then
    echo "Uso: $0 <interfaz>"
    exit 1
fi

echo "🔍 Monitoreando interfaz: $IFACE"
echo "📄 Guardando IPs en: $LOG"
touch "$LOG"

while true; do
    echo "⏳ Capturando tráfico..."
    
    IP_LIST=$(tcpdump -i "$IFACE" -n -c 200 2>/dev/null | \
              grep -oE 'IP [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
              awk '{print $2}' | sort -u)

    for IP in $IP_LIST; do
        if ! grep -Fxq "$IP" "$LOG"; then
            echo "⚠️  IP detectada: $IP"
            echo "$IP" >> "$LOG"

            iptables -A INPUT -s "$IP" -j DROP
            echo "🛑 IP bloqueada: $IP"
        fi
    done

    sleep 3
done

🧪 9. Pruebas
Prueba 1 — Generar tráfico falso:
ping -c 4 <tu_ip>

Prueba 2 — Ver bloqueo:
sudo iptables -L INPUT -n | grep DROP

Prueba 3 — Ver monitoreo:
tail -f lista_bloqueo.txt
