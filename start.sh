#!/bin/bash
set -e

# Initialize CUPS config if /etc/cups is empty (first run)
if [ ! -f /etc/cups/cupsd.conf ]; then
    echo "First run: copying default CUPS configuration..."
    cp /usr/share/cups/cupsd.conf.default /etc/cups/cupsd.conf
    cp /usr/share/cups/cups-files.conf.default /etc/cups/cups-files.conf
    cp /usr/share/cups/snmp.conf.default /etc/cups/snmp.conf
    echo "CUPS configuration initialized"
fi

# Create /etc/hp/hplip.conf if missing
if [ ! -f /etc/hp/hplip.conf ]; then
    echo "Creating /etc/hp/hplip.conf..."
    mkdir -p /etc/hp
    cat > /etc/hp/hplip.conf << HPCONF
[hplip]
version=3.22.10

[dirs]
home=/usr/share/hplip
HPCONF
fi

# Create /var/lib/hp/hplip.state if missing (marks plugin as installed)
if [ ! -f /var/lib/hp/hplip.state ]; then
    echo "Creating /var/lib/hp/hplip.state..."
    mkdir -p /var/lib/hp
    cat > /var/lib/hp/hplip.state << HPSTATE
[plugin]
installed = 1
eula = 1
version = 3.22.10
HPSTATE
fi

# Clean up stale pid files from previous runs
rm -f /run/dbus/pid
rm -f /run/avahi-daemon/pid
rm -f /var/run/cups/cupsd.pid

# Create D-Bus directory and start D-Bus
mkdir -p /run/dbus
dbus-daemon --system --fork

# Start Avahi daemon in background
/usr/sbin/avahi-daemon --daemonize --no-chroot

# USB hotplug monitor: watches /dev/bus/usb for new devices and
# signals CUPS to re-enumerate so a printer connected after startup
# is detected without a container restart.
usb_hotplug_monitor() {
    echo "USB hotplug monitor started"
    # inotifywait watches for new USB device nodes appearing
    while inotifywait -q -r -e create /dev/bus/usb 2>/dev/null; do
        echo "USB device connected — notifying CUPS..."
        # Give the kernel a moment to finish device enumeration
        sleep 2
        # SIGHUP tells cupsd to reload and re-enumerate devices
        pkill -HUP cupsd 2>/dev/null || true
    done
}

usb_hotplug_monitor &
HOTPLUG_PID=$!

# Ensure the monitor is cleaned up when the container exits
cleanup() {
    kill "$HOTPLUG_PID" 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# Start CUPS in foreground
exec /usr/sbin/cupsd -f

