#!/usr/bin/env bash
# Aracno prototipo — fase 1: crea due tentacoli (Debian e Arch) come cartelle
#   /var/lib/machines/debian   (via debootstrap)
#   /var/lib/machines/arch     (via immagine ufficiale archlinux esportata da Docker)
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }
M=/var/lib/machines

write_nspawn() {  # configurazione comune di un tentacolo
  cat > "/etc/systemd/nspawn/$1.nspawn" <<EOF
[Exec]
Boot=yes
PrivateUsers=no

[Network]
VirtualEthernet=no
EOF
}

# --- Debian -------------------------------------------------------------
if [[ ! -d $M/debian/etc ]]; then
  echo ">> Creo tentacolo debian (qualche minuto)..."
  debootstrap --include=systemd,systemd-sysv,dbus,procps,iproute2 \
    trixie "$M/debian" http://deb.debian.org/debian
  echo debian > "$M/debian/etc/hostname"
fi
write_nspawn debian

# --- Arch ---------------------------------------------------------------
if [[ ! -d $M/arch/etc ]]; then
  echo ">> Creo tentacolo arch..."
  docker pull archlinux:latest
  cid=$(docker create archlinux:latest /bin/true)
  mkdir -p "$M/arch"
  docker export "$cid" | tar -xpf - -C "$M/arch"
  docker rm "$cid" >/dev/null
  rm -f "$M/arch/.dockerenv"
  echo arch > "$M/arch/etc/hostname"
fi
write_nspawn arch

echo
echo "Tentacoli creati:"
du -sh "$M"/debian "$M"/arch
