#!/usr/bin/env bash
# Aracno — T17: prova un'ISO (o un disco installato) in QEMU/KVM e legge l'esito dalla
# console seriale. Senza sudo (l'utente ha accesso a /dev/kvm).
#
#   iso/prova-vm.sh ISO                 avvia, aspetta il login sulla seriale, poi chiude
#   iso/prova-vm.sh --disco FILE.qcow2  avvia da un disco (dopo un'installazione)
# Opzioni:
#   --aspetta REGEX   testo da aspettare sulla seriale (default: "login:")
#   --tempo SECONDI   tempo massimo (default 300)
#   --resta           lascia la VM accesa dopo l'esito (per guardarla o usarla)
#   --senza-finestra  niente finestra (solo seriale)
#   --senza-rete      VM senza rete (prova dei fili offline)
#   --disco-nuovo GB  aggiunge un disco vuoto (per l'installazione) in iso/out/disco.qcow2
#   --invio-dopo S    preme Invio nella VM dopo S secondi (menù di GRUB senza timeout)
#   --foto FILE.png   all'esito salva lo schermo della VM (anche senza finestra)
# Monitor di QEMU in iso/out/monitor.sock: `iso/prova-vm.sh --monitor "comando"` lo usa da
# un altro terminale (es. "sendkey ret", "screendump /percorso.ppm").
#
# Criteri di T17 (scritti prima): l'ISO di prova di T16 si avvia in UEFI; lo script vede
# "login:" sulla seriale entro il tempo massimo ed esce con codice 0 (1 se non lo vede).
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
OUT=$R/iso/out
OVMF=/usr/share/OVMF/OVMF_CODE_4M.fd
VARS0=/usr/share/OVMF/OVMF_VARS_4M.fd

aspetta='login:'; tempo=300; resta=0; finestra=1; rete=1; iso=""; disco=""; nuovo=""
invio=""; foto=""
MON=$(cd "$(dirname "$0")" && pwd)/out/monitor.sock
# manda un comando al monitor di QEMU
monitor() {
  python3 - "$MON" "$1" <<'PY'
import socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); s.settimeout(2)
time.sleep(0.2); s.recv(4096)
s.sendall((sys.argv[2] + "\n").encode()); time.sleep(0.5)
try: print(s.recv(65536).decode(errors="replace").strip().splitlines()[-1])
except Exception: pass
PY
}
if [[ ${1:-} == --monitor ]]; then monitor "$2"; exit; fi
while (( $# )); do
  case $1 in
    --aspetta) aspetta=$2; shift ;;
    --tempo) tempo=$2; shift ;;
    --resta) resta=1 ;;
    --senza-finestra) finestra=0 ;;
    --senza-rete) rete=0 ;;
    --disco) disco=$2; shift ;;
    --disco-nuovo) nuovo=$2; shift ;;
    --invio-dopo) invio=$2; shift ;;
    --foto) foto=$2; shift ;;
    -*) echo "opzione sconosciuta: $1"; exit 2 ;;
    *) iso=$1 ;;
  esac
  shift
done
[[ -n $iso || -n $disco ]] || { sed -n '2,15p' "$0"; exit 2; }
[[ -r /dev/kvm ]] || { echo "/dev/kvm non accessibile"; exit 1; }
[[ -f $OVMF ]] || { echo "manca $OVMF: sudo apt install ovmf"; exit 1; }

mkdir -p "$OUT"
LOG=$OUT/seriale.log; : >"$LOG"
VARS=$OUT/ovmf-vars.fd; [[ -f $VARS ]] || cp "$VARS0" "$VARS"

args=(-enable-kvm -machine q35 -cpu host -smp 4 -m 3072
      -drive "if=pflash,format=raw,readonly=on,file=$OVMF"
      -drive "if=pflash,format=raw,file=$VARS"
      -serial "file:$LOG" -device virtio-vga
      -monitor "unix:$MON,server,nowait")
if (( finestra )); then args+=(-display gtk); else args+=(-display none); fi
if (( rete )); then args+=(-nic user,model=virtio-net-pci); else args+=(-nic none); fi
if [[ -n $iso ]]; then args+=(-cdrom "$iso" -boot d); fi
if [[ -n $disco ]]; then args+=(-drive "file=$disco,if=virtio,format=qcow2"); fi
if [[ -n $nuovo ]]; then
  [[ -f $OUT/disco.qcow2 ]] || qemu-img create -f qcow2 "$OUT/disco.qcow2" "${nuovo}G" >/dev/null
  args+=(-drive "file=$OUT/disco.qcow2,if=virtio,format=qcow2")
fi

echo ">> QEMU: ${iso:-$disco} (seriale in $LOG)"
t0=$(date +%s)
qemu-system-x86_64 "${args[@]}" & pid=$!
trap '[[ $resta == 1 ]] || kill $pid 2>/dev/null || true' EXIT

esito=1; premuto=0
while kill -0 "$pid" 2>/dev/null; do
  if [[ -n $invio && $premuto == 0 ]] && (( $(date +%s) - t0 >= invio )); then
    monitor "sendkey ret" >/dev/null; premuto=1; echo "   (Invio premuto dopo ${invio} s)"
  fi
  if grep -qE "$aspetta" "$LOG" 2>/dev/null; then esito=0; break; fi
  (( $(date +%s) - t0 < tempo )) || break
  sleep 1
done
s=$(( $(date +%s) - t0 ))
if [[ -n $foto ]] && kill -0 "$pid" 2>/dev/null; then
  # QEMU salva in PPM; si converte in PNG (più piccolo, si apre ovunque)
  monitor "screendump $OUT/schermo.ppm" >/dev/null; sleep 1
  convert "$OUT/schermo.ppm" "$foto" 2>/dev/null && rm -f "$OUT/schermo.ppm" || foto=$OUT/schermo.ppm
  echo "   schermo della VM: $foto"
fi
if (( esito == 0 )); then
  echo "ok: \"$aspetta\" sulla seriale dopo $s s"
else
  echo "FAIL: \"$aspetta\" non visto in $s s. Ultime righe della seriale:"
  tail -15 "$LOG" | sed 's/^/    /'
fi
if (( resta )); then
  echo "La VM resta accesa (pid $pid). Chiudi la finestra per spegnerla."
  wait "$pid" || true
fi
exit "$esito"
