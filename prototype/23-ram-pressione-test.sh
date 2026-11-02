#!/usr/bin/env bash
# Aracno prototipo — T13: sotto pressione di memoria, da chi prende il kernel?
# Si lancia con sudo. Durata: 2–3 minuti. Non cambia nessuna impostazione: misura soltanto.
#
# Domanda: serve un tetto automatico di RAM per i fili congelati, o il kernel sacrifica già
# da solo le loro pagine (fredde) quando il filo attivo chiede memoria?
# Scenario: arch congelato con 800 MB occupati; in debian (attivo) un programma con 500 MB
# "di lavoro"; poi in debian un secondo programma chiede la RAM libera + 700 MB.
#
# Ipotesi e criteri (scritti prima del test):
#   P1 della memoria tolta durante la pressione ai due "residenti" (arch congelato e il
#      lavoro di debian), almeno il 70% viene dal filo congelato. Per debian si conta lo
#      swap del solo servizio di lavoro, non quello del programma che fa pressione.
#   P2 finita la pressione, rileggere i 500 MB di lavoro di debian richiede meno di 1 s
#      (non sono stati mandati in swap)
#   P3 solo misura: tornare su arch e rileggere i suoi 800 MB (quanto costa il risveglio)
#   Nessun processo ucciso dal kernel (oom_kill = 0 in entrambi i fili).
# Se P1–P2 passano: nessun tetto automatico, ci pensa il kernel (decisione in un ADR).
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }
R="$(cd "$(dirname "$0")/.." && pwd)"
O="$R/prototype/aracno"
M=/var/lib/machines
UTENTE=${SUDO_USER:-xenon}
LAVORO=500; FERMO=800; OLTRE=700

fails=0
ok()   { echo "  ok: $*"; }
fail() { echo "  FAIL: $*"; fails=$((fails + 1)); }
cg()   { echo "/sys/fs/cgroup/machine.slice/systemd-nspawn@$1.service"; }
mb()   { awk '{printf "%d", $1/1048576}' "$1"; }
ram()  { mb "$(cg "$1")/memory.current"; }
swp()  { mb "$(cg "$1")/memory.swap.current"; }
# swap del solo servizio U dentro il filo F (cgroup del container, visibile dall'host)
swp_unit() { mb "$(cg "$1")/payload/system.slice/$2.service/memory.swap.current"; }
ooms() { awk '/^oom_kill /{print $2}' "$(cg "$1")/memory.events"; }
avail(){ awk '/^MemAvailable/{printf "%d", $2/1024}' /proc/meminfo; }
hop()  { runuser -u "$UTENTE" -- /usr/local/bin/aracno hop "$1" >/dev/null; }
# avvia memhog MB nel filo F come unit U; aspetta "ok:" nel suo log
hog() {
  local f=$1 u=$2 mb=$3 log=$M/$1/var/tmp/$2.log
  rm -f "$log"
  systemd-run -M "$f" --unit="$u" --collect --quiet /bin/sh -c "exec /var/tmp/memhog $mb > /var/tmp/$u.log 2>&1"
  for _ in $(seq 240); do grep -qE '^(ok:|ERRORE)' "$log" 2>/dev/null && break; sleep 0.5; done
  grep -q '^ok:' "$log" || { echo "  memhog $u in $f non è partito: $(cat "$log" 2>/dev/null)"; return 1; }
}
verifica() {  # rilegge la memoria di memhog e stampa il tempo
  local f=$1 u=$2 log=$M/$1/var/tmp/$2.log
  systemctl -M "$f" kill --signal=SIGUSR1 "$u"
  for _ in $(seq 240); do grep -qE '^verify' "$log" && break; sleep 0.25; done
  grep '^verify' "$log" | tail -1
}
ferma() { systemctl -M "$1" stop "$2" 2>/dev/null || true; }
pulizia() {
  hop debian 2>/dev/null || true
  ferma debian aracno-lavoro; ferma debian aracno-pressione
  hop arch 2>/dev/null || true; ferma arch aracno-fermo; hop debian 2>/dev/null || true
}
trap pulizia EXIT

echo ">> Preparazione: memhog statico nei due fili"
gcc -O2 -static -o /tmp/aracno-memhog "$R/prototype/memhog.c"
for f in arch debian; do install -m 755 /tmp/aracno-memhog "$M/$f/var/tmp/memhog"; done
rm -f /tmp/aracno-memhog
hop arch
hog arch aracno-fermo $FERMO
hop debian          # arch congelato con i suoi 800 MB
hog debian aracno-lavoro $LAVORO
sleep 2
a0=$(ram arch); as0=$(swp arch); d0=$(ram debian); ds0=$(swp_unit debian aracno-lavoro); o0=$(( $(ooms arch) + $(ooms debian) ))
echo "    prima: arch ${a0} MB (swap ${as0}), debian ${d0} MB (lavoro in swap: ${ds0}), RAM disponibile $(avail) MB"

echo; echo ">> P1: debian chiede la RAM libera + ${OLTRE} MB"
chiesti=$(( $(avail) + OLTRE ))
echo "    pressione: ${chiesti} MB"
hog debian aracno-pressione $chiesti || fail "il programma di pressione non è partito"
sleep 5
a1=$(ram arch); as1=$(swp arch); d1=$(ram debian); ds1=$(swp_unit debian aracno-lavoro)
echo "    durante: arch ${a1} MB (swap ${as1}), debian ${d1} MB (lavoro in swap: ${ds1}), RAM disponibile $(avail) MB"
da_arch=$(( a0 - a1 > 0 ? a0 - a1 : 0 ))
da_debian=$(( ds1 - ds0 > 0 ? ds1 - ds0 : 0 ))
tot=$(( da_arch + da_debian ))
echo "    tolti al filo congelato: ${da_arch} MB; tolti al lavoro del filo attivo: ${da_debian} MB"
if (( tot > 0 )); then
  q=$(( da_arch * 100 / tot ))
  (( q >= 70 )) && ok "P1: il ${q}% viene dal filo congelato" || fail "P1: solo il ${q}% dal filo congelato"
else
  fail "P1: nessuna memoria tolta (la pressione non è bastata?)"
fi

echo; echo ">> P2: finita la pressione, debian rilegge i suoi ${LAVORO} MB"
ferma debian aracno-pressione; sleep 1
v=$(verifica debian aracno-lavoro); echo "    $v"
ms=$(sed -n 's/.* in \([0-9]*\) ms/\1/p' <<<"$v")
[[ $v == "verify ok"* && -n $ms ]] && (( ms < 1000 )) && ok "P2: ${ms} ms" || fail "P2: $v"

echo; echo ">> P3: si torna su arch e si rileggono i suoi ${FERMO} MB (solo misura)"
t0=$(date +%s%N); hop arch; echo "    switch: $(( ($(date +%s%N) - t0) / 1000000 )) ms"
v=$(verifica arch aracno-fermo); echo "    $v"
[[ $v == "verify ok"* ]] && ok "P3: dati intatti" || fail "P3: $v"

o1=$(( $(ooms arch) + $(ooms debian) ))
(( o1 == o0 )) && ok "nessun processo ucciso dal kernel" || fail "oom_kill: $(( o1 - o0 ))"

echo
if (( fails == 0 )); then
  echo "ESITO T13: PASS (il kernel sacrifica da solo il filo congelato: nessun tetto automatico)"
else
  echo "ESITO T13: FAIL ($fails controlli). Incolla l'output completo: decidiamo la politica sui numeri."
  exit 1
fi
