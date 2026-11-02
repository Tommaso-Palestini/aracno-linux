#!/usr/bin/env bash
# Aracno — T16: il costruttore dell'ISO.
# Una cartella Debian trixie in /var/lib/aracno/costruttore, usata con systemd-nspawn (senza
# boot). Non è un filo: sta fuori da /var/lib/machines, quindi machined e aracnod non la vedono.
# Il live-build di Ubuntu (3.0~a57) è troppo vecchio per trixie: si usa quello di Debian, qui dentro.
#
#   sudo iso/costruttore.sh             crea il costruttore (o lo aggiorna)
#   sudo iso/costruttore.sh --verifica  controlli di T16 (sotto)
#   sudo iso/costruttore.sh --shell     una shell dentro, per le prove a mano
#
# Ipotesi e criteri di T16 (scritti prima):
#   C1 nel costruttore `lb --version` risponde (live-build di trixie)
#   C2 il workspace di Aracno (aracnod, aracno, aracno-menu) compila contro le librerie di trixie,
#      con il cargo di Debian, senza rpath verso ~/.local
#   C3 live-build produce un'ISO minima di prova (senza desktop): misura del tempo e della dimensione
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

R="$(cd "$(dirname "$0")/.." && pwd)"
C=/var/lib/aracno/costruttore
MIRROR=http://deb.debian.org/debian
PACCHETTI=(
  live-build xorriso squashfs-tools mtools dosfstools ca-certificates curl gnupg
  cargo rustc pkg-config build-essential gettext
  libgtk-4-dev libgtk4-layer-shell-dev
)

# esegue un comando nel costruttore: sorgenti di Aracno in /src (sola lettura), lavoro in /lavoro
dentro() {
  mkdir -p "$R/iso/out" "$C/lavoro"
  systemd-nspawn -q --settings=no --register=no --capability=all \
    --bind-ro="$R:/src" --bind="$R/iso/out:/out" \
    -D "$C" --chdir=/lavoro "$@"
}

crea() {
  if [[ ! -d $C/etc ]]; then
    echo ">> debootstrap trixie in $C (qualche minuto)"
    mkdir -p "$(dirname "$C")"
    debootstrap --variant=minbase trixie "$C" "$MIRROR"
  fi
  mkdir -p "$C/lavoro" "$R/iso/out"
  echo ">> pacchetti per costruire"
  dentro /bin/sh -c "export DEBIAN_FRONTEND=noninteractive
    apt-get update -q && apt-get install -y -q --no-install-recommends ${PACCHETTI[*]}"
  echo ">> costruttore pronto: $C ($(du -sh --one-file-system "$C" | cut -f1))"
}

verifica() {
  local fails=0 t0 iso
  ok()   { echo "  ok: $*"; }
  fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }

  echo ">> C1: live-build"
  v=$(dentro lb --version 2>&1 | head -1) && ok "lb $v" || fail "lb: $v"

  echo; echo ">> C2: il workspace di Aracno con le librerie di trixie"
  t0=$(date +%s)
  if dentro /bin/sh -c 'export CARGO_TARGET_DIR=/lavoro/target CARGO_HOME=/lavoro/cargo
        cd /src/aracno && cargo build --release --locked --workspace 2>&1 | tail -3'; then
    for b in aracnod aracno aracno-menu; do
      [[ -x $C/lavoro/target/release/$b ]] && ok "$b compilato" || fail "$b mancante"
    done
    rp=$(dentro /bin/sh -c 'readelf -d /lavoro/target/release/aracno-menu | grep -iE "rpath|runpath" || true')
    [[ -z $rp ]] && ok "aracno-menu senza rpath (libreria di sistema)" || fail "aracno-menu con rpath: $rp"
    echo "    compilazione: $(( $(date +%s) - t0 )) s; $(dentro rustc --version)"
  else
    fail "cargo build"
  fi

  echo; echo ">> C3: ISO minima di prova (live-build, senza desktop; 10–20 minuti)"
  t0=$(date +%s)
  dentro /bin/sh -c 'set -e; rm -rf /lavoro/prova-lb; mkdir -p /lavoro/prova-lb; cd /lavoro/prova-lb
    lb config --distribution trixie --architectures amd64 --binary-images iso-hybrid \
      --archive-areas "main" --debian-installer none --bootappend-live "boot=live components console=ttyS0" \
      --mirror-bootstrap http://deb.debian.org/debian --mirror-binary http://deb.debian.org/debian >/dev/null
    lb build > /lavoro/prova-lb.log 2>&1 || { tail -30 /lavoro/prova-lb.log; exit 1; }
    cp live-image-amd64.hybrid.iso /out/prova-lb.iso' && iso=$R/iso/out/prova-lb.iso || true
  if [[ -f ${iso:-} ]]; then
    ok "ISO di prova: $(du -h "$iso" | cut -f1) in $(( ($(date +%s) - t0) / 60 )) min ($iso)"
    chown "${SUDO_USER:-root}:" "$iso" 2>/dev/null || true
  else
    fail "live-build non ha prodotto l'ISO (log: $C/lavoro/prova-lb.log)"
  fi

  echo
  if (( fails == 0 )); then echo "ESITO T16: PASS (costruttore pronto, Aracno compila su trixie, ISO di prova fatta)"
  else echo "ESITO T16: FAIL ($fails controlli). Incolla l'output completo."; exit 1; fi
}

case ${1:-} in
  "") crea ;;
  --verifica) [[ -d $C/etc ]] || crea; verifica ;;
  --shell) dentro /bin/bash ;;
  *) echo "uso: $0 [--verifica|--shell]"; exit 2 ;;
esac
