#!/bin/bash
set -e

# ── CUPS configuration ─────────────────────────────────────────────────────
# Only created if missing — never overrides an existing mounted config.

if [ ! -f /etc/cups/cupsd.conf ]; then
    echo "Creating /etc/cups/cupsd.conf..."
    mkdir -p /etc/cups
    cp /usr/share/cups/cupsd.conf.default /etc/cups/cupsd.conf

    # Listen on all interfaces, not just localhost
    sed -i 's|^Listen localhost:631|Listen 0.0.0.0:631|' /etc/cups/cupsd.conf

    # Allow remote access from local network for root location
    sed -i '/^<Location \/>$/{
        n
        /Allow/!i\  Allow @LOCAL
    }' /etc/cups/cupsd.conf

    # Allow remote access from local network for /admin
    sed -i '/^<Location \/admin>$/{
        n
        /Allow/!i\  Allow @LOCAL
    }' /etc/cups/cupsd.conf

    # Allow remote access from local network for /admin/conf
    sed -i '/^<Location \/admin\/conf>$/{
        n
        /Allow/!i\  Allow @LOCAL
    }' /etc/cups/cupsd.conf

    echo "CUPS configuration initialized (listening on 0.0.0.0:631, @LOCAL allowed)"
fi

if [ ! -f /etc/cups/cups-files.conf ]; then
    echo "Creating /etc/cups/cups-files.conf..."
    mkdir -p /etc/cups
    cp /usr/share/cups/cups-files.conf.default /etc/cups/cups-files.conf
    echo "cups-files.conf initialized"
fi

if [ ! -f /etc/cups/snmp.conf ]; then
    echo "Creating /etc/cups/snmp.conf..."
    mkdir -p /etc/cups
    cp /usr/share/cups/snmp.conf.default /etc/cups/snmp.conf
    echo "snmp.conf initialized"
fi

# ── HPLIP configuration ────────────────────────────────────────────────────

if [ ! -f /etc/hp/hplip.conf ]; then
    echo "Creating /etc/hp/hplip.conf..."
    mkdir -p /etc/hp
    cat > /etc/hp/hplip.conf << 'HPCONF'
[hplip]
version=3.22.10

[dirs]
home=/usr/share/hplip
HPCONF
    echo "hplip.conf initialized"
fi

if [ ! -f /var/lib/hp/hplip.state ]; then
    echo "Creating /var/lib/hp/hplip.state..."
    mkdir -p /var/lib/hp
    cat > /var/lib/hp/hplip.state << 'HPSTATE'
[plugin]
installed = 1
eula = 1
version = 3.22.10
HPSTATE
    echo "hplip.state initialized"
fi

# ── Stale PID cleanup ──────────────────────────────────────────────────────

rm -f /run/dbus/pid
rm -f /run/avahi-daemon/pid
rm -f /var/run/cups/cupsd.pid

# ── D-Bus ──────────────────────────────────────────────────────────────────

mkdir -p /run/dbus
dbus-daemon --system --fork
echo "D-Bus started"

# ── Avahi ──────────────────────────────────────────────────────────────────

/usr/sbin/avahi-daemon --daemonize --no-chroot
echo "Avahi started"

# ── USB hotplug monitor ────────────────────────────────────────────────────
# Watches /dev/bus/usb for new device nodes and sends SIGHUP to cupsd,
# so a printer connected after startup is detected without a restart.

usb_hotplug_monitor() {
    echo "USB hotplug monitor started"
    while inotifywait -q -r -e create /dev/bus/usb 2>/dev/null; do
        echo "USB device connected — notifying CUPS..."
        sleep 2
        pkill -HUP cupsd 2>/dev/null || true
    done
}

usb_hotplug_monitor &
HOTPLUG_PID=$!

# ── Cleanup on exit ────────────────────────────────────────────────────────

cleanup() {
    echo "Shutting down..."
    kill "$HOTPLUG_PID" 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# ── CUPS (foreground) ──────────────────────────────────────────────────────

echo "Starting CUPS..."
exec /usr/sbin/cupsd -f
