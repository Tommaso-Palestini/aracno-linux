#!/usr/bin/env bash
# Aracno prototipo — fase 4.2: verifica che dentro ogni tentacolo il driver grafico
# sia quello della Radeon (RADV/radeonsi), non il renderer software (llvmpipe).
# Non installa nulla: se mancano gli strumenti, stampa il comando da lanciare.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

M=/var/lib/machines
names() { for d in "$M"/*/; do [[ -d $d/etc ]] && basename "$d"; done; }

# Comando da eseguire dentro il tentacolo, a seconda della distro
pkg_cmd() {
  case $1 in
    debian) echo "apt-get update && apt-get install -y mesa-vulkan-drivers vulkan-tools mesa-utils" ;;
    arch)   echo "pacman -Sy --noconfirm --needed vulkan-radeon vulkan-tools mesa-utils" ;;
    *)      echo "installa vulkan-tools e mesa-utils con il gestore pacchetti di $1" ;;
  esac
}

inside() { systemd-run -M "$1" --quiet --wait --pipe /bin/sh -c "$2" 2>&1; }

FAIL=0
for n in $(names); do
  echo ">> $n"
  # Test headless: glxinfo richiede un display X, quindi si usa solo Vulkan
  if ! inside "$n" 'command -v vulkaninfo >/dev/null' >/dev/null; then
    echo "  manca vulkan-tools. Dentro il tentacolo lancia:"
    echo "    ! sudo machinectl shell $n /bin/sh -c '$(pkg_cmd "$n")'"
    FAIL=$((FAIL + 1)); echo; continue
  fi

  dev=$(inside "$n" 'vulkaninfo --summary 2>/dev/null | sed -n "s/.*deviceName *= *//p" | head -1' || true)
  echo "  Vulkan: ${dev:-nessun dispositivo}"

  if [[ $dev =~ (AMD|RADV|Radeon|Picasso|RAVEN) && ! $dev =~ llvmpipe ]]; then
    echo "  $n: OK (GPU hardware)"
  else
    echo "  $n: FAIL (driver software o non rilevato)"
    FAIL=$((FAIL + 1))
  fi
  echo
done

if (( FAIL == 0 )); then
  echo "ESITO 4.2: PASS (driver hardware in tutti i tentacoli)"
else
  echo "ESITO 4.2: FAIL ($FAIL tentacoli). Incolla l'output completo."
  exit 1
fi
