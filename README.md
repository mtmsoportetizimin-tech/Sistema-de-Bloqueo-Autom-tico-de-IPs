🚧 Firewall Automático de Bloqueo de IPs

Monitoreo continuo + Detección + Bloqueo con iptables

Este proyecto implementa un sistema de detección y bloqueo automático de direcciones IP en Linux mediante análisis continuo de tráfico en tiempo real.

Funciona en: Linux Mint, Ubuntu, Debian, Kali Linux, y derivados.

📦 Requisitos

Instalar dependencias necesarias:

sudo apt update
sudo apt install -y tcpdump iptables net-tools


Permisos:

Usuario con sudo

Acceso a la interfaz de red a monitorear

📁 Estructura del proyecto
auto-firewall/
│
├── bloqueo_continuo.sh   # Script principal
├── lista_bloqueo.txt     # IPs bloqueadas
└── README.md             # Documentación

⚙️ Instalación

Clona el repositorio:

git clone https://github.com/usuario/auto-firewall.git
cd auto-firewall


Da permisos:

chmod +x bloqueo_continuo.sh

▶️ Uso

Ejecuta indicando la interfaz de red:

sudo ./bloqueo_continuo.sh wlx502b73a90122


El programa:

Monitorea tráfico en tiempo real

Detecta IPs nuevas

Bloquea automáticamente con iptables

Guarda IPs en lista_bloqueo.txt

Se ejecuta de forma continua

🔍 Verificar bloqueos
Reglas aplicadas por iptables:
sudo iptables -L INPUT -n --line-numbers

Lista de IPs bloqueadas:
cat lista_bloqueo.txt

🔁 Ejecución en segundo plano

Ejecutar sin cerrar la terminal:

nohup sudo ./bloqueo_continuo.sh wlx502b73a90122 &


Ver si está activo:

ps aux | grep bloqueo_continuo


Detener:

sudo kill -9 <PID>

🛠 Guardar reglas después de reiniciar (opcional)
sudo apt install -y iptables-persistent
sudo netfilter-persistent save

📌 Notas

Puedes añadir IPs manualmente a lista_bloqueo.txt.

Las reglas se añaden solo una vez por IP.

Diseñado para entornos de pruebas y laboratorios de ciberseguridad.
