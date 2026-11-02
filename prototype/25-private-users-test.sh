#!/usr/bin/env bash
# Aracno prototipo — T15: fili con spazio utenti separato (PrivateUsers=pick).
# Oggi (ADR-0001) root nel filo è root dell'host. Con PrivateUsers=pick root nel filo è un
# utente qualsiasi dell'host (UID alto): un programma compromesso nel filo non diventa root
# del sistema. Si lancia con sudo, dalla sessione grafica. `--rimuovi` torna a prima.
# Prima compila (come utente):
#   cd /home/xenon/Desktop/progetti-personal/idea-linux/aracno/spikes/wayland-globali && cargo build --release
#
# Cosa cambia (copie dei file in *.prima-di-t15):
#   - .nspawn: PrivateUsers=pick, PrivateUsersOwnership=map (il kernel traduce la proprietà
#     dei file al volo: nessun file del filo viene modificato, il cambio è reversibile);
#     nei fili solo /dev/dri/renderD128 (disegnare), non card0 (comanda lo schermo)
#   - drop-in gpu.conf: DeviceAllow solo per renderD128
#   - regola udev: renderD* con permessi 0666 (il nodo "render" è fatto per programmi non
#     privilegiati: non comanda lo schermo)
#   - helper del socket Wayland: socket 0777 dentro /run/user/UID (0700, quindi solo il filo
#     e l'utente ci arrivano)
#
# Ipotesi e criteri (scritti prima del test):
#   I1 dentro ogni filo /proc/1/uid_map non è l'identità: 0 → UID dell'host ≥ 65536
#   I2 sull'host il processo principale del filo gira con UID ≥ 65536
#   I3 i file del filo sul disco non cambiano proprietario (etc/passwd resta di root)
#   G1 Vulkan dentro ogni filo usa ancora la Radeon (non llvmpipe)
#   G2 card0 non è visibile dentro i fili
#   W1 da dentro ogni filo 36 protocolli Wayland e nessuno privilegiato (come T14)
#   W2 vkcube da debian apre la finestra
#   A1 aracnod: switch avanti e indietro, stati coerenti
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo, dalla sessione grafica"; exit 1; }
R="$(cd "$(dirname "$0")/.." && pwd)"
O="$R/prototype/aracno"
SP="$R/aracno/spikes/wayland-globali/target/release"
M=/var/lib/machines
CONF=/etc/systemd/nspawn
DROP=/etc/systemd/system
UDEV=/etc/udev/rules.d/70-aracno-render.rules
HELPER=/usr/local/libexec/aracno-socket-sicuro
UTENTE=${SUDO_USER:-xenon}
UIDU=$(id -u "$UTENTE"); RUN=/run/user/$UIDU
PRIVILEGIATI='^(ext_data_control_manager_v1|zwlr_data_control_manager_v1|ext_image_copy_capture_manager_v1|ext_output_image_capture_source_manager_v1|ext_foreign_toplevel_image_capture_source_manager_v1|zcosmic_workspace_image_capture_source_manager_v1|zwp_virtual_keyboard_manager_v1|zwp_input_method_manager_v2|zwlr_layer_shell_v1|ext_session_lock_manager_v1|cosmic_session_lock_layer_manager_v1|zcosmic_toplevel_manager_v1|zcosmic_toplevel_info_v1|ext_foreign_toplevel_list_v1|zwlr_output_manager_v1|zcosmic_output_manager_v1|zwlr_output_power_manager_v1|ext_workspace_manager_v1|zcosmic_workspace_manager_v2|wp_security_context_manager_v1) '

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
names() { for d in "$M"/*/; do [[ -d $d/etc ]] && basename "$d"; done; }
utente() { runuser -u "$UTENTE" -- env XDG_RUNTIME_DIR="$RUN" DBUS_SESSION_BUS_ADDRESS="unix:path=$RUN/bus" "$@"; }
dentro() { local n=$1; shift; systemd-run -M "$n" --quiet --wait --pipe "$@" 2>&1; }
copia() { [[ -f $1.prima-di-t15 ]] || cp -p "$1" "$1.prima-di-t15"; }
rimetti() { [[ -f $1.prima-di-t15 ]] && mv "$1.prima-di-t15" "$1" && echo "  rimesso $1"; }
riavvia_fili() {
  for n in $(names); do
    if systemctl is-active -q "systemd-nspawn@$n.service"; then
      systemctl thaw "systemd-nspawn@$n.service" 2>/dev/null || true
      machinectl poweroff "$n"
      for _ in $(seq 60); do systemctl is-active -q "systemd-nspawn@$n.service" || break; sleep 0.5; done
    fi
    for _ in 1 2 3 4 5; do "$O" start "$n" >/dev/null 2>&1 && break; sleep 1; done
  done
  "$O" switch debian >/dev/null
}
ricarica_udev() { udevadm control --reload; udevadm trigger --subsystem-match=drm --action=change; udevadm settle; }

if [[ ${1:-} == --rimuovi ]]; then
  for n in $(names); do rimetti "$CONF/$n.nspawn" || true; rimetti "$DROP/systemd-nspawn@$n.service.d/gpu.conf" || true; done
  rm -f "$UDEV"; ricarica_udev
  systemctl daemon-reload; riavvia_fili
  echo "Fili di nuovo con PrivateUsers=no (l'helper del socket resta quello nuovo: innocuo)."; exit 0
fi

[[ -x $SP/aracno-socket-sicuro && -x $SP/aracno-wayland-globali ]] || { echo "Compila prima lo spike (vedi l'intestazione)"; exit 1; }

echo ">> Applico il cambio"
printf '# Aracno (T15): il nodo render della GPU, fatto per programmi non privilegiati, è\n# accessibile anche agli utenti mappati dei fili (PrivateUsers=pick). card0 resta chiuso.\nSUBSYSTEM=="drm", KERNEL=="renderD*", MODE="0666"\n' >"$UDEV"
ricarica_udev
echo "  $(stat -c '%a %n' /dev/dri/renderD128), $(stat -c '%a %n' /dev/dri/card0)"
install -m 755 -o root -g root "$SP/aracno-socket-sicuro" "$HELPER"
for n in $(names); do
  utente systemctl --user restart "aracno-wayland@$n.service"
  f=$CONF/$n.nspawn; copia "$f"
  sed -e 's/^PrivateUsers=no$/PrivateUsers=pick\nPrivateUsersOwnership=map/' \
      -e 's#^Bind=/dev/dri$#Bind=/dev/dri/renderD128#' "$f.prima-di-t15" >"$f"
  g=$DROP/systemd-nspawn@$n.service.d/gpu.conf; copia "$g"
  grep -v 'card0' "$g.prima-di-t15" >"$g"
  echo "  $n: $(grep -E '^(PrivateUsers|Bind=/dev)' "$f" | tr '\n' ' ')"
done
sleep 1
for n in $(names); do echo "  socket $n: $(stat -c '%a' "$RUN/aracno-wayland-$n.sock")"; done
systemctl daemon-reload
riavvia_fili

echo; echo ">> I1–I3: spazio utenti"
for n in $(names); do
  "$O" switch "$n" >/dev/null
  mappa=$(dentro "$n" /bin/cat /proc/1/uid_map | awk 'NR==1{print $1, $2, $3}')
  base=$(awk '{print $2}' <<<"$mappa")
  [[ -n $base && $base -ge 65536 ]] && ok "I1 $n: uid_map $mappa" || fail "I1 $n: uid_map '$mappa'"
  capo=$(machinectl show "$n" -p Leader --value)
  u=$(ps -o uid= -p "$capo" | tr -d ' ')
  [[ -n $u && $u -ge 65536 ]] && ok "I2 $n: processo principale (pid $capo) con UID $u sull'host" || fail "I2 $n: UID '$u'"
  p=$(stat -c '%u' "$M/$n/etc/passwd")
  [[ $p == 0 ]] && ok "I3 $n: etc/passwd sul disco resta di root" || fail "I3 $n: proprietario $p"
done

echo; echo ">> G1–G2: GPU"
for n in $(names); do
  "$O" switch "$n" >/dev/null
  dev=$(dentro "$n" /bin/sh -c 'vulkaninfo --summary 2>/dev/null | sed -n "s/.*deviceName *= *//p" | head -1' || true)
  [[ $dev =~ (AMD|RADV|Radeon) && ! $dev =~ llvmpipe ]] && ok "G1 $n: $dev" || fail "G1 $n: '${dev:-nessuna GPU}'"
  dentro "$n" /bin/sh -c 'test ! -e /dev/dri/card0' >/dev/null && ok "G2 $n: card0 non visibile" || fail "G2 $n: card0 visibile"
done

echo; echo ">> W1: protocolli Wayland da dentro"
for n in $(names); do
  "$O" switch "$n" >/dev/null
  install -m 755 "$SP/aracno-wayland-globali" "$M/$n/var/tmp/aracno-wayland-globali"
  lista=$(dentro "$n" --setenv=XDG_RUNTIME_DIR=/run/aracno-wayland --setenv=WAYLAND_DISPLAY=wayland-1 /var/tmp/aracno-wayland-globali || true)
  q=$(grep -c ' ' <<<"$lista" || true); pv=$(grep -E "$PRIVILEGIATI" <<<"$lista" | cut -d' ' -f1 | tr '\n' ' ' || true)
  if grep -q '^xdg_wm_base ' <<<"$lista" && [[ -z $pv ]]; then ok "W1 $n: $q protocolli, nessuno privilegiato"
  else fail "W1 $n: $q protocolli; privilegiati: ${pv:-nessuno}; $(head -2 <<<"$lista")"; fi
done

echo; echo ">> A1: aracnod"
for n in arch debian; do
  runuser -u "$UTENTE" -- /usr/local/bin/aracno hop "$n" >/dev/null && [[ $(runuser -u "$UTENTE" -- /usr/local/bin/aracno where) == "$n" ]] \
    && ok "A1 hop $n" || fail "A1 hop $n"
done

echo; echo ">> W2: vkcube da debian per 6 secondi: guarda se compare la finestra"
dentro debian --setenv=XDG_RUNTIME_DIR=/run/aracno-wayland --setenv=WAYLAND_DISPLAY=wayland-1 \
  /bin/sh -c 'timeout 6 vkcube --wsi wayland >/dev/null 2>&1; true' >/dev/null
read -r -p "  ? È comparsa la finestra con il cubo? [s/n] " r </dev/tty
[[ $r == s* || $r == S* ]] && ok "W2 vkcube" || fail "W2 vkcube"

echo
if (( fails == 0 )); then
  echo "ESITO T15: PASS (root nel filo non è root dell'host; GPU, Wayland e aracnod funzionano)"
else
  echo "ESITO T15: FAIL ($fails controlli). Incolla l'output completo. Per tornare indietro: $0 --rimuovi"
  exit 1
fi
