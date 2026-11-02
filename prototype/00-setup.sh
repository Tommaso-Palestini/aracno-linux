#!/usr/bin/env bash
# Aracno prototipo — fase 0: installa gli strumenti sull'host ("la testa")
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

apt-get update
apt-get install -y systemd-container debootstrap debian-archive-keyring

mkdir -p /var/lib/machines /etc/systemd/nspawn
echo "OK: systemd-nspawn $(systemd-nspawn --version | head -1 | awk '{print $2}') pronto."
