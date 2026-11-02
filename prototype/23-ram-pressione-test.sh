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
#
# Primo giro (2026-11-02), senza protezione: P1 61% (646 MB dal congelato, 409 MB dal
# lavoro del filo attivo), P2 1172 ms, P3 1740 ms per 800 MB. Il kernel da solo non basta.
# PROTEGGI=SIZE (es. 1G): durante la prova il filo attivo ha MemoryLow=SIZE (il kernel non
# gli toglie memoria sotto quella soglia finché può prenderla altrove), poi si toglie.
# Ipotesi: con la protezione P1 ≥ 90% e P2 < 300 ms.
# Secondo giro, PROTEGGI=1G: nessun effetto (63%). Difetti del test: (1) la pressione nasce
# dentro debian, quindi MemoryLow sul filo intero non distingue il lavoro dal resto;
# (2) il lavoro riempiva 500 MB e poi stava fermo: pagine fredde quanto quelle del filo
# congelato. Terzo giro: il lavoro tocca la sua memoria ogni secondo (come un'app in uso),
# prima e durante la pressione; si misura senza protezione.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Esegui con sudo"; exit 1; }
R="$(cd "$(dirname "$0")/.." && pwd)"
O="$R/prototype/aracno"
M=/var/lib/machines
UTENTE=${SUDO_USER:-xenon}
LAVORO=500; FERMO=800; OLTRE=700
SOGLIA_P1=70; SOGLIA_P2=1000

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
  local f=$1 u=$2 log=$M/$1/var/tmp/$2.log n0
  # aspetta una riga NUOVA: il tocco continuo ne ha già scritte molte
  n0=$(grep -c '^verify' "$log" || true)
  systemctl -M "$f" kill --signal=SIGUSR1 "$u"
  for _ in $(seq 240); do (( $(grep -c '^verify' "$log" || true) > n0 )) && break; sleep 0.25; done
  grep '^verify' "$log" | tail -1
}
ferma() { systemctl -M "$1" stop "$2" 2>/dev/null || true; }
# il lavoro di debian rilegge la sua memoria ogni secondo, come un'applicazione in uso
TOCCA=""
tocca_avvia() {
  ( while :; do systemctl -M debian kill --signal=SIGUSR1 aracno-lavoro 2>/dev/null || true; sleep 1; done ) &
  TOCCA=$!
}
tocca_ferma() { [[ -n $TOCCA ]] && kill "$TOCCA" 2>/dev/null; wait "$TOCCA" 2>/dev/null || true; TOCCA=""; }
pulizia() {
  tocca_ferma
  systemctl set-property --runtime systemd-nspawn@debian.service MemoryLow=0 2>/dev/null || true
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
if [[ -n ${PROTEGGI:-} ]]; then
  systemctl set-property --runtime systemd-nspawn@debian.service MemoryLow="$PROTEGGI"
  echo "    protezione: debian MemoryLow=$PROTEGGI ($(mb "$(cg debian)/memory.low") MB)"
  SOGLIA_P1=90; SOGLIA_P2=300
fi
tocca_avvia
sleep 6   # il lavoro diventa "caldo"
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
  (( q >= SOGLIA_P1 )) && ok "P1: il ${q}% viene dal filo congelato (soglia ${SOGLIA_P1}%)" || fail "P1: solo il ${q}% dal filo congelato (soglia ${SOGLIA_P1}%)"
else
  fail "P1: nessuna memoria tolta (la pressione non è bastata?)"
fi

echo; echo ">> P2: finita la pressione, debian rilegge i suoi ${LAVORO} MB"
ferma debian aracno-pressione; tocca_ferma; sleep 1.5
v=$(verifica debian aracno-lavoro); echo "    $v"
ms=$(sed -n 's/.* in \([0-9]*\) ms/\1/p' <<<"$v")
[[ $v == "verify ok"* && -n $ms ]] && (( ms < SOGLIA_P2 )) && ok "P2: ${ms} ms (soglia ${SOGLIA_P2})" || fail "P2: $v (soglia ${SOGLIA_P2} ms)"

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
