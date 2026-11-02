#!/usr/bin/env bash
# Aracno prototipo — fase 4.3: la VRAM allocata da un filo congelato resta occupata?
# Sequenza: debian alloca → switch ad arch → arch alloca → pulizia.
# Misura: VRAM (sysfs dell'host) a ogni passo, tempo di switch, esito di ogni allocazione.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }

O="$(dirname "$0")/aracno"
SRC="$(dirname "$0")/vkalloc.c"
MB=${MB:-512}
TOL=64          # MB di tolleranza sulle letture VRAM
SOGLIA_MS=150
A=debian
B=arch
M=/var/lib/machines
SYS=/sys/class/drm/card0/device/mem_info_vram_used

vram()      { awk '{printf "%d", $1/1048576}' "$SYS"; }
inside()    { systemd-run -M "$1" --quiet --wait --pipe /bin/sh -c "$2" 2>&1; }
alloc_log() { cat "$M/$1/var/tmp/vkalloc.log" 2>/dev/null || true; }
ok_of()     { alloc_log "$1" | grep -q '^ok:'; }
near()      { (( $1 >= $2 - TOL && $1 <= $2 + TOL )); }

start_alloc() {
  systemctl -M "$1" stop aracno-vram 2>/dev/null || true
  rm -f "$M/$1/var/tmp/vkalloc.log"
  systemd-run -M "$1" --unit=aracno-vram --quiet \
    /bin/sh -c "/var/tmp/vkalloc $MB > /var/tmp/vkalloc.log 2>&1"
  for _ in $(seq 30); do
    alloc_log "$1" | grep -q -E '^(ok:|ERRORE)' && break
    sleep 0.5
  done
  alloc_log "$1" | head -3
}

echo ">> Compilazione di vkalloc nei fili"
for n in $A $B; do
  if ! systemctl is-active -q "systemd-nspawn@$n.service"; then
    echo "$n è spenta: avviala con aracno start"; exit 1
  fi
  install -m 644 "$SRC" "$M/$n/var/tmp/vkalloc.c"
  if ! inside "$n" 'gcc -O2 -o /var/tmp/vkalloc /var/tmp/vkalloc.c -lvulkan'; then
    echo "Compilazione fallita in $n. Installa gcc e gli header Vulkan:"
    echo "  debian: ! sudo machinectl shell debian /bin/sh -c 'apt-get update && apt-get install -y gcc libvulkan-dev'"
    echo "  arch:   ! sudo machinectl shell arch /bin/sh -c 'pacman -Sy --noconfirm --needed gcc vulkan-headers'"
    exit 1
  fi
  echo "  $n: ok"
done

echo; echo ">> Stato iniziale"
"$O" switch "$A" >/dev/null
base=$(vram); echo "  VRAM: ${base} MB"

echo; echo ">> 1. $A alloca ${MB} MB"
start_alloc "$A"
v1=$(vram); echo "  VRAM: ${v1} MB (+$((v1 - base)))"

echo; echo ">> 2. switch → $B"
out=$("$O" switch "$B"); echo "$out"
ms=$(sed -n 's/.* in \([0-9]*\) ms/\1/p' <<<"$out")

echo; echo ">> 3. $B alloca ${MB} MB (mentre $A è congelata)"
start_alloc "$B"
v2=$(vram); echo "  VRAM: ${v2} MB (attese ~$((base + 2 * MB)) se $A tiene ancora la sua VRAM)"

echo; echo ">> 4. pulizia: prima $A, poi $B"
"$O" switch "$A" >/dev/null
systemctl -M "$A" stop aracno-vram 2>/dev/null || true
sleep 2
v3=$(vram); echo "  VRAM dopo stop di $A: ${v3} MB (attesa ~$((base + MB)))"
"$O" switch "$B" >/dev/null
systemctl -M "$B" stop aracno-vram 2>/dev/null || true
sleep 2
v4=$(vram); echo "  VRAM dopo stop di $B: ${v4} MB (attesa ~${base})"

echo
fails=0
ok_of "$A" || { echo "FAIL: allocazione di $A non riuscita"; fails=$((fails + 1)); }
ok_of "$B" || { echo "FAIL: allocazione di $B non riuscita"; fails=$((fails + 1)); }
near "$v2" $((base + 2 * MB)) || { echo "FAIL: VRAM con entrambe le allocazioni fuori tolleranza"; fails=$((fails + 1)); }
near "$v3" $((base + MB))    || { echo "FAIL: VRAM dopo stop di $A non si è liberata"; fails=$((fails + 1)); }
near "$v4" "$base"           || { echo "FAIL: VRAM non tornata al livello iniziale"; fails=$((fails + 1)); }
[[ -n $ms ]] && (( ms < SOGLIA_MS )) || { echo "FAIL: switch ${ms:-?} ms (soglia ${SOGLIA_MS} ms)"; fails=$((fails + 1)); }

if (( fails == 0 )); then
  echo "ESITO 4.3: PASS (VRAM di $A resta occupata da congelata, si libera allo stop; switch ${ms} ms)"
else
  echo "ESITO 4.3: FAIL ($fails controlli). Incolla l'output completo."
  exit 1
fi
