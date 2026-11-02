#!/usr/bin/env bash
# Aracno prototipo — T14: i fili ricevono un socket Wayland "etichettato"
# (wp_security_context_v1) invece di quello normale: COSMIC nasconde loro i protocolli
# privilegiati (appunti letti di nascosto, cattura dello schermo, tastiera virtuale,
# layer-shell, blocco schermo, gestione di finestre e monitor), come fa con Flatpak.
# Si lancia con sudo, dalla sessione grafica. `--rimuovi` rimette il socket normale.
# Prima compila (come utente):
#   cd /home/xenon/Desktop/progetti-personal/idea-linux/aracno/spikes/wayland-globali && cargo build --release
#
# Misura del 2026-11-02 dall'host: socket normale 59 protocolli, socket etichettato 36
# (23 nascosti, tutti quelli privilegiati).
#
# Ipotesi e criteri (scritti prima del test):
#   W1 per ogni filo un servizio utente aracno-wayland@FILO tiene vivo il socket
#      /run/user/UID/aracno-wayland-FILO.sock
#   W2 da DENTRO ogni filo nessuno dei protocolli privilegiati è visibile, wl_compositor e
#      xdg_wm_base sì
#   W3 vkcube lanciato da debian apre ancora la sua finestra sul desktop
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo, dalla sessione grafica"; exit 1; }
R="$(cd "$(dirname "$0")/.." && pwd)"
O="$R/prototype/aracno"
SP="$R/aracno/spikes/wayland-globali/target/release"
M=/var/lib/machines
CONF=/etc/systemd/nspawn
UTENTE=${SUDO_USER:-xenon}
UIDU=$(id -u "$UTENTE")
RUN=/run/user/$UIDU
HELPER=/usr/local/libexec/aracno-socket-sicuro
UNITA=/etc/systemd/user/aracno-wayland@.service
PRIVILEGIATI='data_control|image_copy_capture|image_capture_source|virtual_keyboard|input_method|layer_shell|session_lock|toplevel_manager|toplevel_info|output_manager|output_power|workspace|foreign_toplevel'

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
names() { for d in "$M"/*/; do [[ -d $d/etc ]] && basename "$d"; done; }
utente() { runuser -u "$UTENTE" -- env XDG_RUNTIME_DIR="$RUN" DBUS_SESSION_BUS_ADDRESS="unix:path=$RUN/bus" "$@"; }
riavvia_fili() {
  for n in $(names); do
    if systemctl is-active -q "systemd-nspawn@$n.service"; then
      systemctl thaw "systemd-nspawn@$n.service" 2>/dev/null || true
      machinectl poweroff "$n"
      for _ in $(seq 60); do systemctl is-active -q "systemd-nspawn@$n.service" || break; sleep 0.5; done
    fi
    "$O" start "$n" >/dev/null
  done
  "$O" switch debian >/dev/null
}

if [[ ${1:-} == --rimuovi ]]; then
  for n in $(names); do
    [[ -f $CONF/$n.nspawn.prima-di-t14 ]] && mv "$CONF/$n.nspawn.prima-di-t14" "$CONF/$n.nspawn" && echo "  $n: .nspawn rimesso"
    utente systemctl --user disable --now "aracno-wayland@$n.service" 2>/dev/null || true
  done
  rm -f "$UNITA" "$HELPER"; utente systemctl --user daemon-reload
  riavvia_fili; echo "Socket normale rimesso."; exit 0
fi

for b in aracno-socket-sicuro aracno-wayland-globali; do
  [[ -x $SP/$b ]] || { echo "Manca $SP/$b: compila prima (vedi l'intestazione)"; exit 1; }
done

echo ">> W1: helper e servizi utente"
install -D -m 755 -o root -g root "$SP/aracno-socket-sicuro" "$HELPER"
cat >"$UNITA" <<EOF
[Unit]
Description=Aracno: socket Wayland etichettato per il filo %i
PartOf=graphical-session.target
After=graphical-session.target

[Service]
ExecStart=$HELPER %t/aracno-wayland-%i.sock %i
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF
utente systemctl --user daemon-reload
for n in $(names); do
  utente systemctl --user enable --now "aracno-wayland@$n.service" 2>&1 | grep -v Created || true
  for _ in $(seq 20); do [[ -S $RUN/aracno-wayland-$n.sock ]] && break; sleep 0.25; done
  [[ -S $RUN/aracno-wayland-$n.sock ]] && ok "$n: $RUN/aracno-wayland-$n.sock" || fail "$n: socket assente"
done

echo; echo ">> Configurazione dei fili (copia in .nspawn.prima-di-t14)"
for n in $(names); do
  f=$CONF/$n.nspawn
  [[ -f $f.prima-di-t14 ]] || cp -p "$f" "$f.prima-di-t14"
  # via ogni Bind del socket Wayland (anche il vecchio /run/octo-wayland), poi quello nuovo
  grep -vE '^Bind=/run/user/[0-9]+/(wayland-[0-9]+|aracno-wayland-[a-z0-9-]+\.sock):' "$f.prima-di-t14" >"$f"
  printf 'Bind=%s/aracno-wayland-%s.sock:/run/aracno-wayland/wayland-1\n' "$RUN" "$n" >>"$f"
  echo "  $n: $(grep 'aracno-wayland' "$f")"
done
riavvia_fili

echo; echo ">> W2: protocolli visti da dentro ogni filo"
for n in $(names); do
  install -m 755 "$SP/aracno-wayland-globali" "$M/$n/var/tmp/aracno-wayland-globali"
  lista=$(systemd-run -M "$n" --quiet --wait --pipe \
    --setenv=XDG_RUNTIME_DIR=/run/aracno-wayland --setenv=WAYLAND_DISPLAY=wayland-1 \
    /var/tmp/aracno-wayland-globali 2>&1 || true)
  quanti=$(grep -c ' ' <<<"$lista" || true)
  privilegiati=$(grep -E "$PRIVILEGIATI" <<<"$lista" | cut -d' ' -f1 | tr '\n' ' ' || true)
  echo "    $n: $quanti protocolli"
  if grep -q '^wl_compositor ' <<<"$lista" && grep -q '^xdg_wm_base ' <<<"$lista"; then
    ok "$n: finestre normali possibili (wl_compositor, xdg_wm_base)"
  else
    fail "$n: mancano i protocolli di base: $(head -3 <<<"$lista")"
  fi
  [[ -z $privilegiati ]] && ok "$n: nessun protocollo privilegiato" || fail "$n: visibili $privilegiati"
done

echo; echo ">> W3: vkcube da debian per 6 secondi: guarda se compare la finestra"
systemd-run -M debian --quiet --wait --pipe \
  --setenv=XDG_RUNTIME_DIR=/run/aracno-wayland --setenv=WAYLAND_DISPLAY=wayland-1 \
  /bin/sh -c 'timeout 6 vkcube --wsi wayland >/dev/null 2>&1; true'
read -r -p "  ? È comparsa la finestra con il cubo? [s/n] " r </dev/tty
[[ $r == s* || $r == S* ]] && ok "W3 vkcube" || fail "W3 vkcube"

echo
if (( fails == 0 )); then
  echo "ESITO T14: PASS (i fili vedono solo i protocolli di un'applicazione normale)"
else
  echo "ESITO T14: FAIL ($fails controlli). Incolla l'output completo. Per tornare indietro: $0 --rimuovi"
  exit 1
fi
