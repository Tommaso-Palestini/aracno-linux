#!/usr/bin/env bash
# Aracno — costruisce l'ISO nel costruttore (iso/costruttore.sh) con live-build.
#
#   sudo iso/costruisci.sh           ISO normale   → iso/out/aracno-AAAAMMGG-amd64.iso
#   sudo iso/costruisci.sh --prova   ISO di prova  → iso/out/aracno-AAAAMMGG-amd64-prova.iso
#     (aggiunge iso/prova/: rapporto automatico sulla console seriale, protocolli Wayland
#      della sessione grafica; serve alle verifiche in VM, non va mai su una chiavetta vera)
#   RIPULISCI=1 sudo iso/costruisci.sh   riparte da zero, cache dei pacchetti compresa
#
# Configurazione: iso/config/ (liste di pacchetti, file, hook). La cache dei pacchetti resta
# nel costruttore tra un giro e l'altro.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }
R="$(cd "$(dirname "$0")/.." && pwd)"
C=/var/lib/aracno/costruttore
prova=0; [[ ${1:-} == --prova ]] && prova=1
NOME=aracno-$(date +%Y%m%d)-amd64$( (( prova )) && echo -prova)
[[ -d $C/etc ]] || "$R/iso/costruttore.sh"

dentro() {
  systemd-nspawn -q --settings=no --register=no --capability=all \
    --bind-ro="$R:/src" --bind="$R/iso/out:/out" -D "$C" --chdir=/lavoro "$@"
}
RUSTENV="export CARGO_HOME=/lavoro/cargo RUSTUP_HOME=/opt/rust/rustup PATH=/opt/rust/cargo/bin:\$PATH"

t0=$(date +%s)
if (( prova )); then
  echo ">> strumenti di prova (spike wayland-globali)"
  dentro /bin/sh -c "$RUSTENV CARGO_TARGET_DIR=/lavoro/target-spike
    cd /src/aracno/spikes/wayland-globali && cargo build --release --locked 2>&1 | tail -1"
fi

echo ">> configurazione di live-build"
dentro /bin/sh -c "set -e
  mkdir -p /lavoro/aracno-iso && cd /lavoro/aracno-iso
  if [ -n '${RIPULISCI:-}' ]; then lb clean --purge >/dev/null 2>&1 || true; else lb clean >/dev/null 2>&1 || true; fi
  rm -rf config/package-lists config/includes.chroot config/hooks/normal/9*-aracno* config/bootloaders
  lb config >/dev/null \
    --distribution trixie --architectures amd64 --binary-images iso-hybrid \
    --archive-areas 'main contrib non-free-firmware' --debian-installer none \
    --mirror-bootstrap http://deb.debian.org/debian --mirror-binary http://deb.debian.org/debian \
    --iso-volume 'Aracno Linux' --iso-application 'Aracno Linux' --iso-publisher 'Aracno' \
    --image-name aracno \
    --bootappend-live 'boot=live components quiet splash username=aracno hostname=aracno locales=en_US.UTF-8 keyboard-layouts=it console=ttyS0,115200 console=tty0'
  cp -r /src/iso/config/package-lists config/
  [ -d /src/iso/config/includes.chroot ] && cp -a /src/iso/config/includes.chroot config/ || true
  # GRUB: conto alla rovescia di 5 s e menù anche sulla seriale (T17: live-build aspetta per sempre)
  [ -d /usr/share/live/build/bootloaders/grub-pc ] || { echo 'manca bootloaders/grub-pc in live-build'; exit 1; }
  mkdir -p config/bootloaders && cp -r /usr/share/live/build/bootloaders/grub-pc config/bootloaders/
  printf '\n# Aracno\nset timeout=5\nserial --unit=0 --speed=115200\nterminal_input console serial\nterminal_output gfxterm serial\n' >> config/bootloaders/grub-pc/config.cfg
"
if (( prova )); then
  dentro /bin/sh -c "set -e; cd /lavoro/aracno-iso
    mkdir -p config/includes.chroot config/hooks/normal
    cp -a /src/iso/prova/includes.chroot/. config/includes.chroot/
    install -D -m 755 /lavoro/target-spike/release/aracno-wayland-globali config/includes.chroot/usr/local/libexec/aracno-wayland-globali
    install -D -m 755 /lavoro/target-spike/release/aracno-socket-sicuro config/includes.chroot/usr/local/libexec/aracno-socket-sicuro
    cp /src/iso/prova/hooks/*.hook.chroot config/hooks/normal/"
fi

echo ">> lb build (la prima volta 30–60 minuti; log in $C/lavoro/aracno-iso.log)"
if ! dentro /bin/sh -c "cd /lavoro/aracno-iso && lb build > /lavoro/aracno-iso.log 2>&1"; then
  tail -40 "$C/lavoro/aracno-iso.log"; echo "ESITO: lb build fallito"; exit 1
fi
src=$(ls "$C"/lavoro/aracno-iso/*.iso | head -1)
cp "$src" "$R/iso/out/$NOME.iso"
chown "${SUDO_USER:-root}:" "$R/iso/out/$NOME.iso" 2>/dev/null || true
echo "ESITO: $R/iso/out/$NOME.iso ($(du -h "$R/iso/out/$NOME.iso" | cut -f1)) in $(( ($(date +%s) - t0) / 60 )) min"
