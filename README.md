# cups-container

> **Personal project** — A self-hosted, Docker/Podman-ready CUPS print server with full HP printer support via HPLIP and its proprietary plugin. Built for home-lab and home-server use.

[![Build & Push](https://github.com/mmBesar/cups-container/actions/workflows/build.yml/badge.svg)](https://github.com/mmBesar/cups-container/actions/workflows/build.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-mmbesar%2Fcups--container-blue?logo=github)](https://github.com/mmBesar/cups-container/pkgs/container/cups-container)
[![Platforms](https://img.shields.io/badge/platforms-amd64%20%7C%20arm64%20%7C%20riscv64-informational)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## What this is

A minimal, self-contained CUPS print server running on Debian trixie-slim, with:

- **CUPS** — the de-facto standard Unix print system
- **HPLIP** — HP's Linux Imaging and Printing drivers, including the proprietary binary plugin installed at build time (no `hp-plugin` required at runtime)
- **Avahi** — mDNS/DNS-SD so your printer appears automatically on the local network (AirPrint, IPP Everywhere)
- **USB hotplug** — connecting your printer *after* the container starts is fully supported; no restart needed

Image tags follow the CUPS package version in Debian trixie, so you always know exactly what you are running. The CI checks for new versions every Monday and only builds when something actually changed.

---

## Supported printers

Any HP printer supported by **HPLIP 3.22.10** should work, including:

- HP LaserJet series (P, M, Pro, Enterprise)
- HP DeskJet / OfficeJet / ENVY series
- HP PageWide series
- HP Color LaserJet series

For the full compatibility list see the [HPLIP supported devices page](https://hplipopensource.com/hplip-web/supported_devices/index.html).

Non-HP printers supported by standard CUPS/IPP drivers will also work — the container is a general CUPS server; HP support is just pre-baked in.

---

## Image tags

| Tag | Meaning |
|-----|---------|
| `latest` | Most recent successful build |
| `2.4.7-1+b1` | Exact CUPS package version from Debian trixie |

Tags are updated automatically whenever the Debian trixie package version changes.

---

## Quick start

### Docker

```bash
docker run -d \
  --name cups \
  --restart unless-stopped \
  --network host \
  -v cups-config:/etc/cups \
  -v /dev/bus/usb:/dev/bus/usb \
  --privileged \
  -p 631:631 \
  ghcr.io/mmbesar/cups-container:latest
```

### Docker Compose

```yaml
services:
  cups:
    image: ghcr.io/mmbesar/cups-container:latest
    container_name: cups
    restart: unless-stopped
    network_mode: host          # required for mDNS/Avahi to work
    privileged: true            # required for USB device access
    ports:
      - "631:631"
    volumes:
      - cups-config:/etc/cups   # persists your printer config across restarts
      - /dev/bus/usb:/dev/bus/usb
    environment:
      - TZ=Africa/Cairo         # set your timezone

volumes:
  cups-config:
```

> **Why `privileged`?**
> USB device access and Avahi mDNS both require elevated permissions inside the container. If you prefer not to use `--privileged`, you can instead pass `--device /dev/bus/usb --cap-add NET_ADMIN --cap-add SYS_ADMIN` — but YMMV depending on your host.

---

## Accessing the CUPS web interface

Once the container is running, open:

```
http://<your-server-ip>:631
```

From there you can add printers, manage jobs, and configure sharing. CUPS will prompt for credentials — use the Linux user credentials of the host, or configure CUPS authentication to your liking via the persistent `/etc/cups` volume.

### Adding your HP printer

1. Open `http://<server>:631/admin`
2. Click **Add Printer**
3. CUPS will list detected USB and network printers — select yours
4. Choose the HP driver (hpcups) — the proprietary plugin is already installed
5. Set it as default if desired

---

## USB hotplug

The container includes a lightweight USB hotplug monitor (`inotifywait` on `/dev/bus/usb`). When you plug in a printer after the container has already started, CUPS is automatically signalled to re-enumerate devices within a couple of seconds — **no restart required**.

---

## Persistent configuration

Mount `/etc/cups` as a named volume (as shown above) to preserve:

- All added printers
- Job history
- Custom CUPS configuration

On first start the container bootstraps a clean default config. Subsequent starts reuse whatever is in the volume.

---

## Building locally

```bash
git clone https://github.com/mmBesar/cups-container.git
cd cups-container

docker build \
  --build-arg HPLIP_VERSION=3.22.10 \
  -t cups-container:local \
  .
```

---

## Credits & upstream projects

This project would not exist without the excellent work of:

| Project | What it provides | License |
|---------|-----------------|---------|
| [CUPS](https://github.com/OpenPrinting/cups) — OpenPrinting | The print server itself | Apache-2.0 |
| [HPLIP](https://developers.hp.com/hp-linux-imaging-and-printing) — HP | HP printer drivers and tooling | GPL-2.0 / proprietary plugin |
| [Debian](https://www.debian.org/) | Base OS, package management | Various |
| [Avahi](https://avahi.org/) | mDNS/DNS-SD / AirPrint discovery | LGPL-2.1 |
| [inotify-tools](https://github.com/inotify-tools/inotify-tools) | USB hotplug detection | GPL-2.0 |
| [OpenPrinting](https://openprinting.github.io/) | CUPS filters and HPLIP plugin hosting | Various |

---

## Personal project notice

This is a **personal home-lab project**, shared publicly in case it is useful to others. It is not affiliated with, endorsed by, or supported by HP, OpenPrinting, or the Debian project.

- No guarantees of stability, security hardening, or long-term maintenance
- Issues and PRs are welcome but may not be addressed promptly
- Use at your own risk

---

## License

[MIT](LICENSE) — do whatever you want with it; credit is appreciated but not required.
