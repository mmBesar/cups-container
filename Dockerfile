FROM debian:trixie-slim

ARG HPLIP_VERSION=3.22.10

# Install all required packages
RUN apt-get update && apt-get install -y \
    cups \
    cups-filters \
    printer-driver-hpcups \
    hplip \
    avahi-daemon \
    dbus \
    ca-certificates \
    wget \
    inotify-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Manually install HP proprietary plugin files
# This bypasses hp-plugin which is broken in Debian's dfsg package
RUN PLUGIN_URL="https://www.openprinting.org/download/printdriver/auxfiles/HP/plugins" && \
    mkdir -p /tmp/hplip-plugin && \
    cd /tmp/hplip-plugin && \
    wget -q "${PLUGIN_URL}/hplip-${HPLIP_VERSION}-plugin.run" && \
    wget -q "${PLUGIN_URL}/hplip-${HPLIP_VERSION}-plugin.run.asc" && \
    sh hplip-${HPLIP_VERSION}-plugin.run --noexec --target /tmp/hplip-plugin/extracted && \
    # Create required plugin directories
    mkdir -p \
        /usr/share/hplip/data/firmware \
        /usr/share/hplip/prnt/plugins \
        /usr/share/hplip/fax/plugins \
        /usr/share/hplip/scan/plugins && \
    # Install firmware files
    cp /tmp/hplip-plugin/extracted/*.fw.gz /usr/share/hplip/data/firmware/ && \
    # Install x86_64 plugin .so files to prnt/plugins
    cp /tmp/hplip-plugin/extracted/lj-x86_64.so          /usr/share/hplip/prnt/plugins/ && \
    cp /tmp/hplip-plugin/extracted/hbpl1-x86_64.so       /usr/share/hplip/prnt/plugins/ && \
    cp /tmp/hplip-plugin/extracted/bb_soap-x86_64.so     /usr/share/hplip/prnt/plugins/ && \
    cp /tmp/hplip-plugin/extracted/bb_marvell-x86_64.so  /usr/share/hplip/prnt/plugins/ && \
    cp /tmp/hplip-plugin/extracted/bb_escl-x86_64.so     /usr/share/hplip/scan/plugins/ && \
    cp /tmp/hplip-plugin/extracted/fax_marvell-x86_64.so /usr/share/hplip/fax/plugins/ && \
    # Set correct permissions
    chmod 755 \
        /usr/share/hplip/prnt/plugins/*.so \
        /usr/share/hplip/fax/plugins/*.so \
        /usr/share/hplip/scan/plugins/*.so && \
    chmod 644 /usr/share/hplip/data/firmware/*.fw.gz && \
    # Create symlinks - THIS IS THE KEY MISSING PIECE
    # hpcups looks for lj.so not lj-x86_64.so
    ln -sf /usr/share/hplip/prnt/plugins/lj-x86_64.so         /usr/share/hplip/prnt/plugins/lj.so && \
    ln -sf /usr/share/hplip/prnt/plugins/hbpl1-x86_64.so      /usr/share/hplip/prnt/plugins/hbpl1.so && \
    ln -sf /usr/share/hplip/prnt/plugins/bb_soap-x86_64.so    /usr/share/hplip/prnt/plugins/bb_soap.so && \
    ln -sf /usr/share/hplip/prnt/plugins/bb_marvell-x86_64.so /usr/share/hplip/prnt/plugins/bb_marvell.so && \
    ln -sf /usr/share/hplip/scan/plugins/bb_escl-x86_64.so    /usr/share/hplip/scan/plugins/bb_escl.so && \
    ln -sf /usr/share/hplip/fax/plugins/fax_marvell-x86_64.so /usr/share/hplip/fax/plugins/fax_marvell.so && \
    # Cleanup
    rm -rf /tmp/hplip-plugin && \
    apt-get remove -y wget && apt-get autoremove -y && apt-get clean

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 631

CMD ["/start.sh"]

