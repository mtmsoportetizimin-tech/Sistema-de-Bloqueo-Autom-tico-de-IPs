# README actualizado - Sistema de Bloqueo Automático de IPs

Proyecto mejorado: ahora utiliza ipset para gestionar bloqueos a gran escala, incluye archivo de configuración, whitelist y una unidad systemd para ejecución como servicio.

Requisitos
---------

- Sistema Linux con ipset, iptables, tcpdump, iproute2
- (Opcional) ipcalc para soporte avanzado de whitelist CIDR

Instalación (ejemplo en Debian/Ubuntu)
-------------------------------------

```bash
sudo apt update
sudo apt install -y ipset iptables tcpdump iproute2 ipcalc
```

Configurar e iniciar
--------------------

1. Copia el archivo de configuración ejemplo y edítalo:

```bash
cp config.ini.example config.ini
# editar config.ini: INTERFACE, BAN_TIMEOUT, etc.
```

2. (Opcional) ajusta whitelist.txt para añadir direcciones internas o evitadas.

3. Da permisos ejecutables y prueba manualmente:

```bash
chmod +x bloqueo_continuo.sh
sudo ./bloqueo_continuo.sh --iface eth0
```

4. Instalar la unidad systemd (como root):

```bash
# copia el servicio a systemd
sudo cp bloqueo-continuo.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now bloqueo-continuo.service
sudo systemctl status bloqueo-continuo.service
```

Logs
----
Los logs se escriben en el directorio especificado por LOG_DIR (por defecto ./logs_escaneos). Hay un ejemplo de configuración de logrotate en logrotate/auto-firewall.

Notas de seguridad
------------------
- Ejecuta estos scripts sólo en entornos controlados y de pruebas. Manipulan iptables e ipset y pueden bloquear conectividad.
- Revisa whitelist.txt para evitar auto-bloqueos de rangos internos.
- Por defecto BAN_TIMEOUT=86400 (24h). Cámbialo a 0 para hacer bloqueos permanentes.

Restauración
------------
Si necesitas eliminar las reglas y el ipset manualmente:

```bash
sudo iptables -D INPUT -m set --match-set auto_firewall_set src -j DROP || true
sudo ipset destroy auto_firewall_set || true
```

Contribuciones
--------------
Pull requests bienvenidos. Para cambios grandes, crea una rama y abre un PR apuntando a main.
